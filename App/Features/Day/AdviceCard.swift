import DayTrackCore
import SwiftData
import SwiftUI

/// Подсказки советчика для плана дня.
struct AdviceCard: View {
    let dayKey: Int
    let now: Date

    @Environment(\.modelContext) private var context
    @AppStorage("advice.collapsed") private var isCollapsed = false
    @State private var refresh = 0

    var body: some View {
        let _ = refresh
        let items = AdvisorService(context: context).advice(for: dayKey, now: now)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation { isCollapsed.toggle() }
                } label: {
                    HStack {
                        Label("Подсказки: \(items.count)", systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if !isCollapsed {
                    ForEach(items) { advice in
                        AdviceRow(advice: advice) {
                            if let action = advice.action {
                                AdvisorService(context: context).apply(action, dayKey: dayKey)
                            }
                            refresh += 1
                        } onDismiss: {
                            AdvisorPreferences.dismiss(advice.id, dayKey: dayKey)
                            refresh += 1
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct AdviceRow: View {
    let advice: Advice
    let onApply: () -> Void
    let onDismiss: () -> Void

    @State private var isShowingWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(advice.rule.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(advice.text)
                .font(.subheadline)
            if isShowingWhy {
                VStack(alignment: .leading, spacing: 4) {
                    Text(advice.why)
                    Text(advice.basis.text)
                        .italic()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let title = advice.actionTitle {
                    Button(title, action: onApply)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Button(isShowingWhy ? "Скрыть объяснение" : "Почему?") {
                    withAnimation { isShowingWhy.toggle() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Button("Не сейчас", action: onDismiss)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}

/// Мягкая серия: дни с планом и вечерним разбором.
struct StreakLine: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        let today = DayClock.app.key(for: .now)
        let result = AdvisorService(context: context).streak(today: today)
        if result.last30 > 0 {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
                Text(result.streak > 0 ? "Серия: \(daysText(result.streak))" : "Серия начнётся с сегодняшнего разбора")
                Text("· за 30 дней: \(result.last30)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private func daysText(_ count: Int) -> String {
        let mod10 = count % 10, mod100 = count % 100
        let word: String
        if mod10 == 1 && mod100 != 11 { word = "день" }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = "дня" }
        else { word = "дней" }
        return "\(count) \(word)"
    }
}
