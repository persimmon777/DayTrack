import DayTrackCore
import SwiftData
import SwiftUI

/// Форма задачи без времени.
struct TaskEditorSheet: View {
    @Bindable var task: TaskItem
    let categories: [ActivityCategory]
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var categoryID: UUID?
    @State private var isConfirmingDelete = false

    private let estimates = [0, 10, 15, 30, 45, 60, 90, 120, 180]

    init(task: TaskItem, categories: [ActivityCategory], onDelete: @escaping () -> Void) {
        self.task = task
        self.categories = categories
        self.onDelete = onDelete
        _categoryID = State(initialValue: task.category?.uuid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $task.title)
                    CategoryPicker(categories: categories, selection: $categoryID)
                    Picker("Займёт примерно", selection: $task.estimateMinutes) {
                        ForEach(estimates, id: \.self) { minutes in
                            Text(minutes == 0 ? "Не знаю" : DurationText.short(minutes: minutes)).tag(minutes)
                        }
                        if !estimates.contains(task.estimateMinutes) {
                            Text(DurationText.short(minutes: task.estimateMinutes)).tag(task.estimateMinutes)
                        }
                    }
                    Toggle("Сделано", isOn: $task.isDone)
                } footer: {
                    Text("Оценка времени пригодится советчику: он сравнит её с тем, сколько уходит на самом деле.")
                }
                Section {
                    Button("Удалить задачу", role: .destructive) { isConfirmingDelete = true }
                }
            }
            .navigationTitle("Задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        task.category = categories.first { $0.uuid == categoryID }
                        if task.title.trimmingCharacters(in: .whitespaces).isEmpty { task.title = "Задача" }
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Удалить задачу?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive, action: onDelete)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
