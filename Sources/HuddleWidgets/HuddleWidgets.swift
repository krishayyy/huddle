import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HuddleWidgets: WidgetBundle {
    var body: some Widget { HuddleLiveActivity() }
}

private let violet = Color(red: 0.76, green: 0.68, blue: 1.0)
private let cyan = Color(red: 0.62, green: 0.86, blue: 1.0)
private let pink = Color(red: 1.0, green: 0.72, blue: 0.88)

/// The countdown on the lock screen and in the Dynamic Island, so a glance at a locked phone
/// shows how long is left without opening anything.
struct HuddleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HuddleActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color(red: 0.06, green: 0.05, blue: 0.14).opacity(0.85))
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
                        .font(.system(size: 40, weight: .light, design: .rounded))
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
                    .font(.headline).foregroundStyle(.white)
                Text("\(context.state.lockedIn) of \(context.state.total) still locked in")
                    .font(.subheadline)
                    .foregroundStyle(context.state.lockedIn == context.state.total ? cyan : pink)
            }
            Spacer()
            Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
