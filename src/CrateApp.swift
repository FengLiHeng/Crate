import SwiftUI
import AppKit

@main
struct CrateApp: App {
    @NSApplicationDelegateAdaptor(CrateAppDelegate.self) private var appDelegate
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup("Crate") {
            RootView()
                .environment(app)
                .frame(minWidth: 1000, minHeight: 540)
                .preferredColorScheme(app.theme == .dark ? .dark : .light)
                .onAppear {
                    appDelegate.bind(appState: app)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    app.flushPersistence()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    app.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(app.isUpdateBusy)
            }
        }
    }
}
