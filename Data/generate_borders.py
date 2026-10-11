#!/usr/bin/env python3
"""Generates LandkreisApp/county-borders.lzfse from the BKG dataset VG25 (GeoPackage).

These unsimplified borders are only used to assign finds to counties. The map keeps
using the simplified VG250 data from counties.geojson.

Usage:     Data/generate_borders.py /path/to/DE_VG25.gpkg
Requires:  python3 -m pip install shapely pyproj numpy  (macOS, uses compression_tool)

Format (little endian, then LZFSE compressed):
  "LKB1", u32 county count
  per county:  5 byte AGS, u32 polygon count
  per polygon: u32 ring count (first ring is the outer ring)
  per ring:    u32 point count, then lon/lat as i32 in 1e-6 degrees,
               the first point absolute, all others as delta to the previous one
"""
import os
import sqlite3
import struct
import subprocess
import sys
import tempfile

import numpy as np
from pyproj import Transformer
from shapely import transform, wkb
from shapely.geometry import MultiPolygon, Polygon

# Hanau has been kreisfrei since 2026-01-01; VG25 as of 2025-12-31 still lists it in the Main-Kinzig-Kreis.
HANAU_MUNICIPALITY = "06435014"
HANAU_COUNTY = "06415"
MAIN_KINZIG = "06435"
# Deutsch-luxemburgisches Kondominium, not a county
SKIP = {"07932", "07935", "10942"}

SCALE = 1_000_000

gpkg = sys.argv[1] if len(sys.argv) > 1 else sys.exit("Please pass the path to DE_VG25.gpkg")
out = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "LandkreisApp", "county-borders.lzfse"))

to_wgs84 = Transformer.from_crs(25832, 4326, always_xy=True)


def read_geometry(blob):
    envelope = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 7]
    geometry = wkb.loads(bytes(blob[8 + envelope:]))
    return transform(geometry, lambda c: np.column_stack(to_wgs84.transform(c[:, 0], c[:, 1])))


def polygons(geometry):
    if isinstance(geometry, Polygon):
        return [geometry]
    if isinstance(geometry, MultiPolygon):
        return list(geometry.geoms)
    return [g for part in geometry.geoms for g in polygons(part)]


db = sqlite3.connect(gpkg)
counties = {ags: read_geometry(g) for g, ags in db.execute("select geom, AGS from vg25_krs") if ags not in SKIP}
hanau = read_geometry(db.execute("select geom from vg25_gem where AGS = ?", (HANAU_MUNICIPALITY,)).fetchone()[0])
if HANAU_COUNTY not in counties:
    counties[MAIN_KINZIG] = counties[MAIN_KINZIG].difference(hanau)
    counties[HANAU_COUNTY] = hanau

data = bytearray(b"LKB1" + struct.pack("<I", len(counties)))
for ags in sorted(counties):
    polys = polygons(counties[ags])
    data += ags.encode("ascii") + struct.pack("<I", len(polys))
    for poly in polys:
        rings = [poly.exterior, *poly.interiors]
        data += struct.pack("<I", len(rings))
        for ring in rings:
            pts = np.round(np.asarray(ring.coords) * SCALE).astype(np.int64)
            deltas = np.vstack([pts[:1], np.diff(pts, axis=0)]).astype("<i4")
            data += struct.pack("<I", len(pts)) + deltas.tobytes()

with tempfile.NamedTemporaryFile(delete=False) as raw:
    raw.write(data)
subprocess.run(["compression_tool", "-encode", "-a", "lzfse", "-i", raw.name, "-o", out], check=True)
os.unlink(raw.name)
print(f"Done: {out} ({len(counties)} counties, {os.path.getsize(out) // 1024} KB)")
