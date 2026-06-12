import Foundation
import Observation

// 播放状态机（design.md D4），语义严格移植 docs/设计材料/player-app.jsx：
// 播放上下文 ctx + 插播队列 manualQueue，插播结束后回到上下文继续。
@Observable
final class PlayerStore {
    struct Context {
        var ids: [String] = []
        var originalIds: [String] = []
        var pos: Int = -1
    }

    var currentId: String?
    /// 当前曲目是否来自插播（不占用上下文位置）
    var isManual = false
    var isPlaying = false
    var progress: Double = 0
    var volume: Double {
        didSet {
            engine?.setVolume(volume)
            UserDefaults.standard.set(volume, forKey: "lmp-volume")
        }
    }
    var shuffle = false
    var repeatMode: RepeatMode = .off
    var manualQueue: [String] = []
    var ctx = Context()

    // 由 AppState 注入
    @ObservationIgnored var songProvider: (String) -> Song? = { _ in nil }
    @ObservationIgnored var onToast: (String) -> Void = { _ in }

    @ObservationIgnored private var engine: PlaybackEngine?
    @ObservationIgnored private var progressTimer: Timer?
    /// 连续"文件不可用"跳过计数，防止全部缺失 + 列表循环时无限跳过
    @ObservationIgnored private var consecutiveSkips = 0

    init() {
        let saved = UserDefaults.standard.object(forKey: "lmp-volume") as? Double
        volume = saved ?? 0.7
    }

    var currentSong: Song? { currentId.flatMap { songProvider($0) } }

    var upcomingIds: [String] {
        guard ctx.pos + 1 < ctx.ids.count else { return [] }
        return Array(ctx.ids[(ctx.pos + 1)...])
    }

    // MARK: - 启动播放

    /// 从列表开始播放（playFrom）
    func playFrom(_ list: [Song], index: Int, forceShuffle: Bool = false) {
        let ids = list.map(\.id)
        guard !ids.isEmpty else { return }
        let useShuffle = forceShuffle || shuffle
        if forceShuffle && !shuffle { shuffle = true }
        var ordered = ids
        var pos = max(0, min(index, ids.count - 1))
        if useShuffle {
            let startId = index >= 0 ? ids[index] : ids.randomElement()!
            ordered = [startId] + ids.filter { $0 != startId }.shuffled()
            pos = 0
        }
        ctx = Context(ids: ordered, originalIds: ids, pos: pos)
        isManual = false
        startPlaying(id: ordered[pos])
    }

    /// 立即播放单曲：作为插播，不打乱原上下文（playSongNow）
    func playSongNow(_ song: Song) {
        isManual = true
        startPlaying(id: song.id)
    }

    // MARK: - 下一首 / 上一首（next / prev）

    func next() {
        if !manualQueue.isEmpty {
            let head = manualQueue.removeFirst()
            isManual = true
            startPlaying(id: head)
            return
        }
        guard !ctx.ids.isEmpty else { stopPlayback(); return }
        var nextPos = ctx.pos + 1
        if nextPos >= ctx.ids.count {
            if repeatMode == .all {
                nextPos = 0
            } else {
                // 列表末尾自然结束：停在曲目末尾
                pausePlayback()
                progress = currentSong?.duration ?? 0
                return
            }
        }
        ctx.pos = nextPos
        isManual = false
        startPlaying(id: ctx.ids[nextPos])
    }

    func prev() {
        if progress > 3 || isManual {
            seek(to: 0)
            return
        }
        if ctx.pos > 0 {
            ctx.pos -= 1
            isManual = false
            startPlaying(id: ctx.ids[ctx.pos])
        } else {
            seek(to: 0)
        }
    }

    // MARK: - 播放/暂停/进度/音量

    func togglePlay() {
        guard currentId != nil else { return }
        if isPlaying {
            engine?.pause()
            isPlaying = false
            stopProgressTimer()
        } else {
            engine?.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func seek(to time: Double) {
        progress = min(max(0, time), currentSong?.duration ?? 0)
        engine?.seek(to: progress)
    }

    // MARK: - 随机 / 循环（toggleShuffle / cycleRepeat）

    func toggleShuffle() {
        shuffle.toggle()
        guard !ctx.ids.isEmpty else { return }
        if shuffle {
            // 开启：当前曲目保持队首，其余洗牌
            let cur = ctx.ids[max(0, min(ctx.pos, ctx.ids.count - 1))]
            let after = ctx.ids.enumerated().filter { $0.offset != ctx.pos }.map(\.element).shuffled()
            ctx.ids = [cur] + after
            ctx.pos = 0
        } else {
            // 关闭：恢复原始顺序，位置对齐当前曲目
            let curId = (currentId != nil && !isManual) ? currentId! : ctx.ids[max(0, min(ctx.pos, ctx.ids.count - 1))]
            let p = max(0, ctx.originalIds.firstIndex(of: curId) ?? 0)
            ctx.ids = ctx.originalIds
            ctx.pos = p
        }
    }

    func cycleRepeat() {
        repeatMode = repeatMode == .off ? .all : repeatMode == .all ? .one : .off
    }

    // MARK: - 队列操作（playNextSong / addToQueue / clearQueue / playManualAt / playContextAt）

    func playNextSong(_ song: Song) {
        manualQueue.insert(song.id, at: 0)
        onToast("「\(song.title)」将在下一首播放")
    }

    func addToQueue(_ song: Song) {
        manualQueue.append(song.id)
        onToast("已将「\(song.title)」添加到待播清单")
    }

    func clearQueue() {
        manualQueue = []
        let keep = Array(ctx.ids.prefix(ctx.pos + 1))
        ctx.ids = keep
        ctx.originalIds = keep
        onToast("已清空待播清单")
    }

    func playManualAt(_ index: Int) {
        guard manualQueue.indices.contains(index) else { return }
        let id = manualQueue.remove(at: index)
        isManual = true
        startPlaying(id: id)
    }

    func playContextAt(_ index: Int) {
        let newPos = ctx.pos + 1 + index
        guard newPos < ctx.ids.count else { return }
        ctx.pos = newPos
        isManual = false
        startPlaying(id: ctx.ids[newPos])
    }

    func removeManualAt(_ index: Int) {
        guard manualQueue.indices.contains(index) else { return }
        manualQueue.remove(at: index)
    }

    // MARK: - 删除歌曲时同步队列与上下文（handleMenuAction remove）

    func handleSongRemoved(_ songId: String) {
        manualQueue.removeAll { $0 == songId }
        let curId = ctx.ids.indices.contains(ctx.pos) ? ctx.ids[ctx.pos] : nil
        ctx.ids.removeAll { $0 == songId }
        ctx.originalIds.removeAll { $0 == songId }
        if curId == songId {
            ctx.pos = min(ctx.pos, ctx.ids.count - 1)
        } else if let curId {
            ctx.pos = ctx.ids.firstIndex(of: curId) ?? -1
        }
        if currentId == songId {
            stopPlayback()
        }
    }

    // MARK: - 内部：引擎与进度

    private func startPlaying(id: String) {
        guard let song = songProvider(id) else { return }
        engine?.stop()
        engine = nil
        progress = 0
        currentId = id

        if let url = song.fileURL {
            // 真实文件：文件缺失或不可解码时降级跳下一首
            guard FileManager.default.fileExists(atPath: url.path),
                  let e = try? AVAudioPlayerEngine(url: url, volume: volume) else {
                consecutiveSkips += 1
                // 整个队列+上下文都不可播时停止，避免列表循环下无限跳过
                if consecutiveSkips >= ctx.ids.count + manualQueue.count + 1 {
                    onToast("没有可播放的曲目")
                    stopPlayback()
                    return
                }
                onToast("「\(song.title)」的文件不可用，已跳过")
                isPlaying = false
                DispatchQueue.main.async { [weak self] in self?.next() }
                return
            }
            engine = e
        } else {
            // 示例曲目：模拟进度
            engine = SimulatedEngine(duration: song.duration)
        }
        consecutiveSkips = 0

        engine?.onFinished = { [weak self] in
            self?.handleFinished()
        }
        engine?.play()
        isPlaying = true
        startProgressTimer()
    }

    private func handleFinished() {
        if repeatMode == .one {
            seek(to: 0)
            engine?.play()
            isPlaying = true
            startProgressTimer()
        } else {
            next()
        }
    }

    private func pausePlayback() {
        engine?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func stopPlayback() {
        engine?.stop()
        engine = nil
        currentId = nil
        isPlaying = false
        progress = 0
        stopProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying, let engine = self.engine else { return }
            self.progress = engine.currentTime
        }
        // .common 模式：滚动/拖动（eventTracking）期间进度照常刷新
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
