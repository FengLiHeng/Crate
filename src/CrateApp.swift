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
            RootView()
                .environment(app)
                .frame(minWidth: 1000, minHeight: 540)
                .preferredColorScheme(app.theme == .dark ? .dark : .light)
                .onAppear {
                    appDelegate.bind(appState: app)
                    ScreenshotWindowCoordinator.prepare(configuration: screenshotConfiguration)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    app.flushPersistence()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: WindowMetrics.defaultContentWidth,
            height: WindowMetrics.defaultContentHeight
        )
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
