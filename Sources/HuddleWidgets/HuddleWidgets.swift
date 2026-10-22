import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HuddleWidgets: WidgetBundle {
    var body: some Widget { HuddleLiveActivity() }
}

// Same tokens as the app's Theme: ember for the lock, moss for "locked in", cream type.
private let violet = Color(red: 1.0, green: 0.353, blue: 0.122)     // ember
private let cyan = Color(red: 0.710, green: 0.851, blue: 0.612)     // moss
private let pink = Color(red: 1.0, green: 0.353, blue: 0.122)       // ember
private let cream = Color(red: 0.953, green: 0.937, blue: 0.906)

/// The countdown on the lock screen and in the Dynamic Island, so a glance at a locked phone
/// shows how long is left without opening anything.
struct HuddleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuddleActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color(red: 0.047, green: 0.043, blue: 0.039).opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Huddle", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(violet)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.lockedIn)/\(context.state.total) locked in")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "lock.fill").foregroundStyle(violet)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 52)
                    .foregroundStyle(cyan)
            } minimal: {
                Image(systemName: "lock.fill").foregroundStyle(violet)
            }
        }
    }
}

private struct LockScreenCard: View {
    let context: ActivityViewContext<HuddleActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ProgressView(timerInterval: context.attributes.startedAt...context.state.endsAt, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Image(systemName: "lock.fill")
            }
            .progressViewStyle(.circular)
            .tint(violet)
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.groupName)
                    .font(.headline).foregroundStyle(cream)
                Text("\(context.state.lockedIn) of \(context.state.total) still locked in")
                    .font(.subheadline)
                    .foregroundStyle(context.state.lockedIn == context.state.total ? cyan : pink)
            }
            Spacer()
            Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                .font(.system(size: 34, weight: .light, design: .serif))
                .monospacedDigit()
                .foregroundStyle(cream)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
