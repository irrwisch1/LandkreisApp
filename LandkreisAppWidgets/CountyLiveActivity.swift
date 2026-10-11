import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LandkreisAppWidgets: WidgetBundle {
    var body: some Widget {
        CountyLiveActivity()
    }
}

struct CountyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountyActivityAttributes.self) { context in
            CountyActivityView(state: context.state)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusDot(status: state.status, size: 14)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.countyName ?? "Außerhalb Deutschlands")
                        .font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DetailLines(state: state)
                }
            } compactLeading: {
                StatusDot(status: state.status, size: 10)
            } compactTrailing: {
                Text(state.countyName ?? "–")
                    .lineLimit(1)
                    .frame(maxWidth: 90)
            } minimal: {
                StatusDot(status: state.status, size: 10)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

struct CountyActivityView: View {
    let state: CountyActivityAttributes.ContentState
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: small
        default: medium
        }
    }

    /// Used in CarPlay and the watchOS Smart Stack
    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                StatusDot(status: state.status, size: 10)
                Text(state.countyName ?? "Außerhalb Deutschlands")
                    .font(.headline).lineLimit(1)
            }
            Text(state.status.shortText)
                .font(.subheadline)
                .foregroundStyle(state.status.color)
            if let name = state.nextOpenName, let d = state.nextOpenDistance {
                Text("Offen: \(name) \(Format.km(d))")
                    .font(.caption).lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            StatusDot(status: state.status, size: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.countyName ?? "Außerhalb Deutschlands")
                    .font(.headline).lineLimit(1)
                DetailLines(state: state)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}

struct DetailLines: View {
    let state: CountyActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if state.countyName != nil {
                Text(state.status.text)
                    .foregroundStyle(state.status.color)
            }
            if let name = state.nextOpenName, let d = state.nextOpenDistance {
                Text("Nächster offener Kreis:")
                    .foregroundStyle(.secondary)
                Text("\(name), \(Format.km(d))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
    }
}

struct StatusDot: View {
    let status: CountyStatus
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}
