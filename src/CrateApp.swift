import SwiftUI
import AppKit

@main
struct CrateApp: App {
    @NSApplicationDelegateAdaptor(CrateAppDelegate.self) private var appDelegate
    @State private var app: AppState
    private let screenshotConfiguration: ScreenshotLaunchConfiguration?

    init() {
        let configuration = ScreenshotLaunchConfiguration.parse(arguments: ProcessInfo.processInfo.arguments)
        screenshotConfiguration = configuration
        if let configuration {
            AppState.storeDirectoryOverride = configuration.storeDirectoryURL
        }
        _app = State(initialValue: AppState(screenshotScene: configuration?.scene))
    }

    var body: some Scene {
        WindowGroup("Crate") {
            CrateRootView(
                app: app,
                appDelegate: appDelegate,
                screenshotConfiguration: screenshotConfiguration
            )
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

private struct CrateRootView: View {
    let app: AppState
    let appDelegate: CrateAppDelegate
    let screenshotConfiguration: ScreenshotLaunchConfiguration?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RootView()
            .environment(app)
            .frame(minWidth: 1000, minHeight: 540)
            .preferredColorScheme(app.themeMode.preferredColorScheme)
            .onAppear {
                app.updateSystemColorScheme(colorScheme)
                appDelegate.bind(appState: app)
                ScreenshotWindowCoordinator.prepare(configuration: screenshotConfiguration)
            }
            .onChange(of: colorScheme) { _, newColorScheme in
                app.updateSystemColorScheme(newColorScheme)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                app.flushPersistence()
            }
    }
}
