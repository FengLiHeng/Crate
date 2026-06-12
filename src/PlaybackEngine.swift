import Foundation
import AVFoundation

// 播放引擎协议（design.md D3）：
// 真实文件走 AVAudioPlayerEngine，无文件的示例曲目走 SimulatedEngine，
// PlayerStore 只面向协议，两条路径行为一致。
protocol PlaybackEngine: AnyObject {
    var onFinished: (() -> Void)? { get set }
    var currentTime: Double { get }
    func play()
    func pause()
    func seek(to time: Double)
    func setVolume(_ volume: Double)
    func stop()
}

// MARK: - 模拟引擎（示例曲目，按真实时间推进进度，无音频输出）

final class SimulatedEngine: PlaybackEngine {
    var onFinished: (() -> Void)?

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

final class AVAudioPlayerEngine: NSObject, PlaybackEngine, AVAudioPlayerDelegate {
    var onFinished: (() -> Void)?

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
            self?.onFinished?()
        }
    }
}
