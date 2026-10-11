import AppKit
import SwiftUI
import TailCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: StudyStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        Task {
            let saved = await store.shutdown()
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
}
typealias ViewState<Value> = SwiftUI.State<Value>

@main struct TailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ViewState<StudyStore> private var store = StudyStore()
    @AppStorage("appearance", store: Preferences.defaults) private var appearance = "system"
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        Window("Tail", id: "main") {
            LibraryView(store: store)
                .preferredColorScheme(
                    appearance == "light" ? .light : appearance == "dark" ? .dark : nil
                )
                .frame(minWidth: 820, minHeight: 600)
                .task {
                    delegate.store = store
                    await store.load()
                }
                .onChange(of: phase) { _, value in if value != .active { store.saveAgain() } }
        }
        .defaultSize(width: 1160, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 학습") { store.newStudy = true }.keyboardShortcut("n").disabled(
                    store.busy != nil || store.loadFailed)
            }
            CommandMenu("학습") {
                Button("답변 제출") { if let q = store.currentQuestion { store.submit(q.id) } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(
                        store.busy != nil || store.currentQuestion?.isAnswering != true
                            || store.currentQuestion?.draft.trimmed.isEmpty != false)
                Button("생성 취소") { store.cancel() }.keyboardShortcut(".").disabled(store.busy == nil)
                Button("오늘 복습") { store.selection = "today" }.keyboardShortcut(
                    "r", modifiers: [.command, .shift])
                Divider()
                Button("보관함 백업…") { store.backup() }.disabled(store.busy != nil || store.loadFailed)
                Button("백업 복원…") { store.restore() }.disabled(store.busy != nil || store.loadFailed)
            }
        }
        Settings {
            PreferencesView(store: store).preferredColorScheme(
                appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        }
    }
}
