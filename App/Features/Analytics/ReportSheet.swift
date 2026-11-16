import DayTrackCore
import SwiftData
import SwiftUI
import UIKit

/// Отчёт для нейросети: просмотр и копирование.
struct ReportSheet: View {
    let kind: PeriodKind
    let anchorKey: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var report = ""
    @State private var copied: String?

    private var fullText: String { ReportSettings.prompt + "\n\n" + report }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Нажми «Скопировать с запросом» и вставь текст в любую нейросеть. Запрос можно изменить в настройках.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(report)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = fullText
                        copied = "Скопировано вместе с запросом"
                    } label: {
                        Label("Скопировать с запросом", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    HStack {
                        Button {
                            UIPasteboard.general.string = report
                            copied = "Скопирован только отчёт"
                        } label: {
                            Text("Только отчёт").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        ShareLink(item: fullText) {
                            Label("Поделиться", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if let copied {
                        Text(copied)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Отчёт: \(kind.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear {
                report = ReportBuilder(context: context).build(kind: kind, anchorKey: anchorKey)
            }
        }
    }
}

/// Настройка текста запроса.
struct ReportPromptView: View {
    @State private var prompt = ReportSettings.prompt

    var body: some View {
        Form {
            Section {
                TextEditor(text: $prompt)
                    .frame(minHeight: 260)
            } footer: {
                Text("Этот текст копируется перед отчётом. В нём можно рассказать нейросети о себе и о том, какой разбор тебе нужен.")
            }
            Section {
                Button("Вернуть текст по умолчанию") {
                    ReportSettings.resetPrompt()
                    prompt = ReportSettings.prompt
                }
            }
        }
        .navigationTitle("Запрос для нейросети")
        .onChange(of: prompt) { _, value in ReportSettings.prompt = value }
    }
}
