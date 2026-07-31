import AppKit

@MainActor
final class CrateAppDelegate: NSObject, NSApplicationDelegate {
    private weak var appState: AppState?
    private var systemMediaControls: SystemMediaControls?

    func bind(appState: AppState) {
        systemMediaControls?.stop()
        self.appState = appState
        systemMediaControls = SystemMediaControls(appState: appState)
    }

    func applicationWillTerminate(_ notification: Notification) {
        systemMediaControls?.stop()
        systemMediaControls = nil
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let player = appState?.player
        let hasCurrentSong = player?.currentSong != nil
        let playPauseTitle = player?.isPlaying == true ? "暂停" : "播放"

        menu.addItem(playbackItem(title: "上一首", action: #selector(previousTrack), enabled: hasCurrentSong))
        menu.addItem(playbackItem(title: playPauseTitle, action: #selector(togglePlayback), enabled: hasCurrentSong))
        menu.addItem(playbackItem(title: "下一首", action: #selector(nextTrack), enabled: hasCurrentSong))

        return menu
    }

    @objc func previousTrack() {
        performOnMain { $0.player.prev() }
    }

    @objc func togglePlayback() {
        performOnMain { $0.player.togglePlay() }
    }

    @objc func nextTrack() {
        performOnMain { $0.player.next() }
    }

    private func playbackItem(title: String, action: Selector, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        return item
    }

    private func performOnMain(_ action: (AppState) -> Void) {
        guard let appState else { return }
        action(appState)
    }
}
