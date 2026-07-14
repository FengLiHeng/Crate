import Foundation
import AVFoundation

// 播放引擎协议（design.md D3）：
// 真实文件走 FilePlaybackEngine，无文件的示例曲目走 SimulatedEngine，
// PlayerStore 只面向协议，两条路径行为一致。
protocol PlaybackEngine: AnyObject, Sendable {
    var onFinished: (@Sendable () -> Void)? { get set }
    var onFailed: (@Sendable () -> Void)? { get set }
    var currentTime: Double { get }
    func play()
    func pause()
    func seek(to time: Double)
    func setVolume(_ volume: Double)
    func stop()
}

// MARK: - 模拟引擎（示例曲目，按真实时间推进进度，无音频输出）

final class SimulatedEngine: PlaybackEngine, @unchecked Sendable {
    var onFinished: (@Sendable () -> Void)?
    var onFailed: (@Sendable () -> Void)?

    private let duration: Double
    private var elapsed: Double = 0
    private var startedAt: Date?
    private var finishTimer: Timer?

    init(duration: Double) {
        self.duration = duration
    }

    var currentTime: Double {
        min(duration, elapsed + (startedAt.map { Date().timeIntervalSince($0) } ?? 0))
    }

    func play() {
        guard startedAt == nil else { return }
        startedAt = Date()
        scheduleFinish()
    }

    func pause() {
        elapsed = currentTime
        startedAt = nil
        finishTimer?.invalidate()
    }

    func seek(to time: Double) {
        elapsed = min(max(0, time), duration)
        if startedAt != nil {
            startedAt = Date()
            scheduleFinish()
        }
    }

    func setVolume(_ volume: Double) {}

    func stop() {
        finishTimer?.invalidate()
        startedAt = nil
    }

    private func scheduleFinish() {
        finishTimer?.invalidate()
        let remaining = max(0.05, duration - currentTime)
        let timer = Timer(timeInterval: remaining, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.elapsed = self.duration
            self.startedAt = nil
            self.onFinished?()
        }
        // .common 模式：滚动/拖动期间也能按时触发自动切歌
        RunLoop.main.add(timer, forMode: .common)
        finishTimer = timer
    }

    deinit { finishTimer?.invalidate() }
}

// MARK: - 真实播放引擎（AVFoundation）

final class FilePlaybackEngine: PlaybackEngine, @unchecked Sendable {
    var onFinished: (@Sendable () -> Void)? {
        get { engine.onFinished }
        set { engine.onFinished = newValue }
    }
    var onFailed: (@Sendable () -> Void)? {
        get { engine.onFailed }
        set { engine.onFailed = newValue }
    }

    private let engine: PlaybackEngine

    init(url: URL, volume: Double) throws {
        if let audioPlayerEngine = try? AVAudioPlayerEngine(url: url, volume: volume) {
            engine = audioPlayerEngine
        } else {
            engine = try AVPlayerPlaybackEngine(url: url, volume: volume)
        }
    }

    var currentTime: Double { engine.currentTime }

    func play() { engine.play() }
    func pause() { engine.pause() }
    func seek(to time: Double) { engine.seek(to: time) }
    func setVolume(_ volume: Double) { engine.setVolume(volume) }
    func stop() { engine.stop() }
}

final class AVAudioPlayerEngine: NSObject, PlaybackEngine, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinished: (@Sendable () -> Void)?
    var onFailed: (@Sendable () -> Void)?

    private let player: AVAudioPlayer

    init(url: URL, volume: Double) throws {
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.delegate = self
        player.volume = Float(volume)
        player.prepareToPlay()
    }

    var currentTime: Double { player.currentTime }

    func play() { player.play() }
    func pause() { player.pause() }

    func seek(to time: Double) {
        player.currentTime = min(max(0, time), player.duration)
    }

    func setVolume(_ volume: Double) { player.volume = Float(volume) }

    func stop() { player.stop() }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            if flag {
                self?.onFinished?()
            } else {
                self?.onFailed?()
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.onFailed?()
        }
    }
}

final class AVPlayerPlaybackEngine: PlaybackEngine, @unchecked Sendable {
    var onFinished: (@Sendable () -> Void)?
    var onFailed: (@Sendable () -> Void)? {
        didSet {
            if pendingFailure {
                notifyFailed()
            }
        }
    }

    private let player: AVPlayer
    private let item: AVPlayerItem
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var pendingFailure = false
    private var didNotifyFailure = false

    init(url: URL, volume: Double) throws {
        let asset = AVURLAsset(url: url)
        guard AudioFileSupport.canPlayWithAVAsset(at: url) else {
            throw NSError(domain: "CratePlayback", code: 1)
        }
        item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player.volume = Float(volume)
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            self?.notifyFailed()
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onFinished?()
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFailed()
        }
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func seek(to time: Double) {
        let target = CMTime(seconds: max(0, time), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(volume)
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
    }

    private func notifyFailed() {
        guard !didNotifyFailure else { return }
        guard let onFailed else {
            pendingFailure = true
            return
        }
        pendingFailure = false
        didNotifyFailure = true
        DispatchQueue.main.async {
            onFailed()
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
        }
    }
}
