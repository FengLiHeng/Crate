import SwiftUI
import AppKit

@main
struct CrateApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup("Crate") {
            RootView()
                .environment(app)
                .frame(minWidth: 1000, minHeight: 540)
                .preferredColorScheme(app.theme == .dark ? .dark : .light)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    app.flushPersistence()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 760)
    }
}
