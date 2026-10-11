import Foundation
import Compression

struct ZIPArchive {
    struct Entry {
        let name: String
        fileprivate let header: CentralDirectoryHeader

        var uncompressedSize: Int { Int(header.uncompressedSize) }
    }

    enum ReadError: Error { case invalidArchive, unsupported }

    private enum Method {
        static let stored: UInt16 = 0
        static let deflate: UInt16 = 8
    }

    private static let encryptedFlag: UInt16 = 1 << 0
    private static let maxUncompressedSize = 1_000_000_000

    static func isZIP(_ data: Data) -> Bool {
        data.count >= 4 && ByteReader(data).peekU32() == LocalFileHeader.signature
    }

    private let data: Data
    let entries: [Entry]

    init(data: Data) throws {
        self.data = data
        entries = try Self.readEntries(data)
    }

    func extract(_ entry: Entry) throws -> Data {
        let central = entry.header
        guard central.flags & Self.encryptedFlag == 0 else { throw ReadError.unsupported }
        let offset = Int(central.localHeaderOffset)
        let local = try LocalFileHeader(data, at: offset)
        let start = offset + LocalFileHeader.size + Int(local.nameLength) + Int(local.extraLength)
        let size = Int(central.compressedSize)
        guard start + size <= data.count else { throw ReadError.invalidArchive }
        var reader = ByteReader(data, at: start)
        let compressed = reader.bytes(size)

        switch central.method {
        case Method.stored: return compressed
        case Method.deflate: return try Self.inflate(compressed, size: entry.uncompressedSize)
        default: throw ReadError.unsupported
        }
    }

    private static func readEntries(_ data: Data) throws -> [Entry] {
        let end = try EndOfCentralDirectory.find(in: data)
        var offset = Int(end.directoryOffset)
        var entries: [Entry] = []
        entries.reserveCapacity(Int(end.totalEntries))

        for _ in 0..<end.totalEntries {
            let header = try CentralDirectoryHeader(data, at: offset)
            let nameStart = offset + CentralDirectoryHeader.size
            guard nameStart + Int(header.nameLength) <= data.count else { throw ReadError.invalidArchive }
            var reader = ByteReader(data, at: nameStart)
            let name = String(decoding: reader.bytes(Int(header.nameLength)), as: UTF8.self)
            entries.append(Entry(name: name, header: header))
            offset = nameStart + Int(header.nameLength) + Int(header.extraLength) + Int(header.commentLength)
        }
        return entries
    }

    private static func inflate(_ source: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        guard !source.isEmpty, size <= maxUncompressedSize else { throw ReadError.invalidArchive }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { dst in
            source.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, size,
                                          src.bindMemory(to: UInt8.self).baseAddress!, source.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ReadError.invalidArchive }
        return output
    }
}

private struct LocalFileHeader {
    static let signature: UInt32 = 0x04034b50
    static let size = 30

    let versionNeeded: UInt16
    let flags: UInt16
    let method: UInt16
    let modificationTime: UInt16
    let modificationDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let nameLength: UInt16
    let extraLength: UInt16

    init(_ data: Data, at offset: Int) throws {
        guard offset + Self.size <= data.count else { throw ZIPArchive.ReadError.invalidArchive }
        var r = ByteReader(data, at: offset)
        guard r.u32() == Self.signature else { throw ZIPArchive.ReadError.invalidArchive }
        versionNeeded = r.u16()
        flags = r.u16()
        method = r.u16()
        modificationTime = r.u16()
        modificationDate = r.u16()
        crc32 = r.u32()
        compressedSize = r.u32()
        uncompressedSize = r.u32()
        nameLength = r.u16()
        extraLength = r.u16()
    }
}

private struct CentralDirectoryHeader {
    static let signature: UInt32 = 0x02014b50
    static let size = 46

    let versionMadeBy: UInt16
    let versionNeeded: UInt16
    let flags: UInt16
    let method: UInt16
    let modificationTime: UInt16
    let modificationDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let nameLength: UInt16
    let extraLength: UInt16
    let commentLength: UInt16
    let diskNumberStart: UInt16
    let internalAttributes: UInt16
    let externalAttributes: UInt32
    let localHeaderOffset: UInt32

    init(_ data: Data, at offset: Int) throws {
        guard offset + Self.size <= data.count else { throw ZIPArchive.ReadError.invalidArchive }
        var r = ByteReader(data, at: offset)
        guard r.u32() == Self.signature else { throw ZIPArchive.ReadError.invalidArchive }
        versionMadeBy = r.u16()
        versionNeeded = r.u16()
        flags = r.u16()
        method = r.u16()
        modificationTime = r.u16()
        modificationDate = r.u16()
        crc32 = r.u32()
        compressedSize = r.u32()
        uncompressedSize = r.u32()
        nameLength = r.u16()
        extraLength = r.u16()
        commentLength = r.u16()
        diskNumberStart = r.u16()
        internalAttributes = r.u16()
        externalAttributes = r.u32()
        localHeaderOffset = r.u32()
    }
}

private struct EndOfCentralDirectory {
    static let signature: UInt32 = 0x06054b50
    static let size = 22
    static let maxCommentLength = 0xFFFF

    let diskNumber: UInt16
    let directoryDisk: UInt16
    let entriesOnDisk: UInt16
    let totalEntries: UInt16
    let directorySize: UInt32
    let directoryOffset: UInt32
    let commentLength: UInt16

    static func find(in data: Data) throws -> EndOfCentralDirectory {
        guard data.count >= size else { throw ZIPArchive.ReadError.invalidArchive }
        let last = data.count - size
        for offset in stride(from: last, through: max(0, last - maxCommentLength), by: -1)
        where ByteReader(data, at: offset).peekU32() == signature {
            return EndOfCentralDirectory(data, at: offset)
        }
        throw ZIPArchive.ReadError.invalidArchive
    }

    private init(_ data: Data, at offset: Int) {
        var r = ByteReader(data, at: offset + 4)
        diskNumber = r.u16()
        directoryDisk = r.u16()
        entriesOnDisk = r.u16()
        totalEntries = r.u16()
        directorySize = r.u32()
        directoryOffset = r.u32()
        commentLength = r.u16()
    }
}

private struct ByteReader {
    let data: Data
    var offset: Int

    init(_ data: Data, at offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    func peekU32() -> UInt32 {
        var copy = self
        return copy.u32()
    }

    mutating func u16() -> UInt16 { read(UInt16.self) }
    mutating func u32() -> UInt32 { read(UInt32.self) }

    mutating func bytes(_ length: Int) -> Data {
        defer { offset += length }
        return data.subdata(in: data.startIndex + offset ..< data.startIndex + offset + length)
    }

    private mutating func read<T: FixedWidthInteger>(_: T.Type) -> T {
        defer { offset += MemoryLayout<T>.size }
        return data.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
    }
}
