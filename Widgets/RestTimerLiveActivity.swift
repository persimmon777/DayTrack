import ActivityKit
import SwiftUI
import WidgetKit

/// Таймер отдыха на экране блокировки.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                    Text(context.isStale ? "Время вышло" : "Осталось")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(timerInterval: context.state.countdownRange(), countsDown: true)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "cup.and.saucer.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.countdownRange(), countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70, alignment: .trailing)
                }
            } compactLeading: {
                Image(systemName: "cup.and.saucer.fill")
            } compactTrailing: {
                Text(timerInterval: context.state.countdownRange(), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "cup.and.saucer.fill")
            }
        }
    }
}
