import AppKit
import Foundation
import MediaPlayer
import Observation

/// 与 macOS 系统媒体命令一一对应，协调器负责将其映射到 PlayerStore。
enum SystemMediaCommand: Equatable, Sendable {
    case play
    case pause
    case togglePlayPause
    case previous
    case next
    case seek(to: Double)
}

/// 发布到系统“正在播放”的纯值快照，避免 MediaPlayer 类型渗入业务状态。
struct SystemNowPlayingSnapshot: Equatable, Sendable {
    var songId: String
    var title: String
    var artist: String
    var albumTitle: String
    var artworkData: Data?
    var duration: Double
    var elapsedTime: Double
    var playbackRate: Double
}

@MainActor
protocol SystemMediaControlsBackend: AnyObject {
    func start(commandHandler: @escaping @MainActor (SystemMediaCommand) -> Bool)
    func publish(_ snapshot: SystemNowPlayingSnapshot?)
    func stop()
}

/// MediaPlayer 框架适配层，只负责系统字典、封面对象与远程命令注册。
@MainActor
final class MediaPlayerSystemMediaControlsBackend: SystemMediaControlsBackend {
    private final class CommandAvailability: @unchecked Sendable {
        private let lock = NSLock()
        private var available = false

        func set(_ value: Bool) {
            lock.lock()
            available = value
            lock.unlock()
        }

        func get() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return available
        }
    }

    private let infoCenter: MPNowPlayingInfoCenter
    private let commandCenter: MPRemoteCommandCenter
    private let commandAvailability = CommandAvailability()
    private var commandHandler: (@MainActor (SystemMediaCommand) -> Bool)?
    private var commandTargets: [(command: MPRemoteCommand, token: Any)] = []
    private var cachedArtworkData: Data?
    private var cachedArtwork: MPMediaItemArtwork?

    init(
        infoCenter: MPNowPlayingInfoCenter = .default(),
        commandCenter: MPRemoteCommandCenter = .shared()
    ) {
        self.infoCenter = infoCenter
        self.commandCenter = commandCenter
    }

    func start(commandHandler: @escaping @MainActor (SystemMediaCommand) -> Bool) {
        stop(removeNowPlayingInfo: false)
        self.commandHandler = commandHandler

        register(commandCenter.playCommand, command: .play)
        register(commandCenter.pauseCommand, command: .pause)
        register(commandCenter.togglePlayPauseCommand, command: .togglePlayPause)
        register(commandCenter.previousTrackCommand, command: .previous)
        register(commandCenter.nextTrackCommand, command: .next)
        registerSeekCommand()
        setCommandsEnabled(false)
    }

    func publish(_ snapshot: SystemNowPlayingSnapshot?) {
        guard let snapshot else {
            clearNowPlayingInfo()
            setCommandsEnabled(false)
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyAlbumTitle: snapshot.albumTitle,
            MPMediaItemPropertyPlaybackDuration: snapshot.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.playbackRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1,
        ]
        if let artwork = artwork(for: snapshot.artworkData) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        commandAvailability.set(true)
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = snapshot.playbackRate > 0 ? .playing : .paused
        setCommandsEnabled(true)
    }

    func stop() {
        stop(removeNowPlayingInfo: true)
    }

    private func stop(removeNowPlayingInfo: Bool) {
        for target in commandTargets {
            target.command.removeTarget(target.token)
        }
        commandTargets.removeAll()
        commandHandler = nil
        setCommandsEnabled(false)
        if removeNowPlayingInfo {
            clearNowPlayingInfo()
        }
    }

    private func register(_ remoteCommand: MPRemoteCommand, command: SystemMediaCommand) {
        let token = remoteCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return self.dispatch(command)
        }
        commandTargets.append((remoteCommand, token))
    }

    private func registerSeekCommand() {
        let remoteCommand = commandCenter.changePlaybackPositionCommand
        let token = remoteCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            return self.dispatch(.seek(to: event.positionTime))
        }
        commandTargets.append((remoteCommand, token))
    }

    nonisolated func dispatch(_ command: SystemMediaCommand) -> MPRemoteCommandHandlerStatus {
        guard commandAvailability.get() else {
            return .noActionableNowPlayingItem
        }

        let handled: Bool
        if Thread.isMainThread {
            handled = MainActor.assumeIsolated {
                self.commandHandler?(command) ?? false
            }
        } else {
            handled = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    self.commandHandler?(command) ?? false
                }
            }
        }
        return handled ? .success : .noActionableNowPlayingItem
    }

    private func artwork(for data: Data?) -> MPMediaItemArtwork? {
        guard let data else {
            cachedArtworkData = nil
            cachedArtwork = nil
            return nil
        }
        if cachedArtworkData == data {
            return cachedArtwork
        }
        cachedArtworkData = data
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            cachedArtwork = nil
            return nil
        }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        cachedArtwork = artwork
        return artwork
    }

    private func setCommandsEnabled(_ enabled: Bool) {
        commandCenter.playCommand.isEnabled = enabled
        commandCenter.pauseCommand.isEnabled = enabled
        commandCenter.togglePlayPauseCommand.isEnabled = enabled
        commandCenter.previousTrackCommand.isEnabled = enabled
        commandCenter.nextTrackCommand.isEnabled = enabled
        commandCenter.changePlaybackPositionCommand.isEnabled = enabled
    }

    private func clearNowPlayingInfo() {
        commandAvailability.set(false)
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
        cachedArtworkData = nil
        cachedArtwork = nil
    }
}

/// 观察应用播放状态并协调系统媒体后端。
@MainActor
final class SystemMediaControls {
    private weak var appState: AppState?
    private let backend: any SystemMediaControlsBackend
    private var stopped = false

    convenience init(appState: AppState) {
        self.init(appState: appState, backend: MediaPlayerSystemMediaControlsBackend())
    }

    init(appState: AppState, backend: any SystemMediaControlsBackend) {
        self.appState = appState
        self.backend = backend
        backend.start { [weak self] command in
            self?.handle(command) ?? false
        }
        observeAndPublish()
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        backend.stop()
    }

    @discardableResult
    func handle(_ command: SystemMediaCommand) -> Bool {
        guard let player = appState?.player, player.currentSong != nil else {
            return false
        }

        switch command {
        case .play:
            if !player.isPlaying {
                player.togglePlay()
            }
        case .pause:
            if player.isPlaying {
                player.togglePlay()
            }
        case .togglePlayPause:
            player.togglePlay()
        case .previous:
            player.prev()
        case .next:
            player.next()
        case .seek(let time):
            player.seek(to: time)
        }
        return true
    }

    private func observeAndPublish() {
        guard !stopped else { return }
        let snapshot = withObservationTracking {
            makeSnapshot()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeAndPublish()
            }
        }
        backend.publish(snapshot)
    }

    private func makeSnapshot() -> SystemNowPlayingSnapshot? {
        guard let appState, let song = appState.player.currentSong else { return nil }
        let album = song.albumId.flatMap { appState.albumsById[$0] }
        return SystemNowPlayingSnapshot(
            songId: song.id,
            title: song.title,
            artist: appState.artistName(for: song),
            albumTitle: appState.albumTitle(for: song),
            artworkData: song.artworkData ?? album?.artworkData,
            duration: song.duration,
            elapsedTime: min(max(0, appState.player.progress), song.duration),
            playbackRate: appState.player.isPlaying ? 1 : 0
        )
    }
}
