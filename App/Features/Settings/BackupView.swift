import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Резервные копии: автокопия в папку, сохранение и восстановление.
struct BackupView: View {
    @Environment(\.modelContext) private var context

    @State private var folderName = BackupService.folderName
    @State private var lastBackup = BackupService.lastBackupDate
    @State private var isPickingFolder = false
    @State private var isExporting = false
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var isImporting = false
    @State private var pendingRestore: BackupSnapshot?
    @State private var message: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Папка", value: folderName ?? "не выбрана")
                if let lastBackup {
                    LabeledContent("Последняя копия", value: lastBackup.formatted(date: .abbreviated, time: .shortened))
                }
                Button(folderName == nil ? "Выбрать папку" : "Сменить папку") { isPickingFolder = true }
                if folderName != nil {
                    Button("Сохранить копию сейчас") {
                        do {
                            let name = try BackupService.writeToFolder(context: context)
                            lastBackup = BackupService.lastBackupDate
                            message = "Копия сохранена: \(name)"
                        } catch {
                            message = "Не удалось сохранить: \(error.localizedDescription)"
                        }
                    }
                    Button("Отключить автокопию", role: .destructive) {
                        BackupService.clearFolder()
                        folderName = nil
                    }
                }
            } header: {
                Text("Автокопия")
            } footer: {
                Text("Раз в день при открытии приложения в эту папку сохраняется копия, хранятся последние 14. Лучше выбрать папку в iCloud Drive: папка «На iPhone» → DayTrack удаляется вместе с приложением.")
            }

            Section {
                Button("Сохранить копию в файл…") {
                    do {
                        exportDocument = BackupDocument(data: try BackupService.encode(BackupService.makeSnapshot(context: context)))
                        isExporting = true
                    } catch {
                        message = "Не удалось подготовить копию: \(error.localizedDescription)"
                    }
                }
                Button("Восстановить из копии…") { isImporting = true }
            } footer: {
                Text("Восстановление заменяет все текущие данные содержимым копии.")
            }
        }
        .navigationTitle("Резервные копии")
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try BackupService.setFolder(url)
                    folderName = BackupService.folderName
                    try BackupService.writeToFolder(context: context)
                    lastBackup = BackupService.lastBackupDate
                    message = "Папка выбрана, первая копия сохранена."
                } catch {
                    message = "Не удалось использовать папку: \(error.localizedDescription)"
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.fileName()
        ) { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    pendingRestore = try BackupService.decode(Data(contentsOf: url))
                } catch {
                    message = "Это не копия DayTrack или файл повреждён."
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Заменить все данные копией?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("Восстановить", role: .destructive) {
                guard let snapshot = pendingRestore else { return }
                do {
                    try BackupService.restore(snapshot, context: context)
                    message = "Данные восстановлены."
                } catch {
                    message = "Не удалось восстановить: \(error.localizedDescription)"
                }
                pendingRestore = nil
            }
        } message: {
            if let snapshot = pendingRestore {
                Text("Копия от \(snapshot.exportedAt.formatted(date: .abbreviated, time: .shortened)). \(snapshot.summary). Текущие данные будут удалены.")
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Понятно", role: .cancel) {}
        }
    }
}
