import Foundation
import Observation

/// 跳过失效曲目时的寻找方向（design.md D3）
enum SkipDirection {
    case forward   // 下一首 / 自动切歌 / 从列表播放：向后找可用曲目
    case backward  // 上一首：向前找可用曲目
}

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
    /// 播放撞到文件缺失/无法解码时回调，供 AppState 即时标记失效（design.md D2）
    @ObservationIgnored var onMissing: (String) -> Void = { _ in }

    @ObservationIgnored private var engine: PlaybackEngine?
    @ObservationIgnored private var progressTimer: Timer?
    /// 本轮跳过已尝试过的曲目 id；候选再次出现说明绕了一圈，全库不可播（design.md D4）
    @ObservationIgnored private var skipVisited: Set<String> = []
    /// 播放代次：异步构造引擎期间用户若已切歌，旧构造结果按代次作废（design.md D5）
    @ObservationIgnored private var playToken = 0

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
    func playFrom(_ list: [Song], index: Int, forceShuffle: Bool = false, rotateFromIndex: Bool = false) {
        let ids = list.map(\.id)
        guard !ids.isEmpty else { return }
        skipVisited.removeAll()
        let useShuffle = forceShuffle || shuffle
        if forceShuffle && !shuffle { shuffle = true }
        var ordered = ids
        var pos = max(0, min(index, ids.count - 1))
        if useShuffle {
            let startId = index >= 0 ? ids[index] : ids.randomElement()!
            ordered = [startId] + ids.filter { $0 != startId }.shuffled()
            pos = 0
        } else if rotateFromIndex, pos > 0 {
            ordered = Array(ids[pos...]) + Array(ids[..<pos])
            pos = 0
        }
        ctx = Context(ids: ordered, originalIds: ids, pos: pos)
        isManual = false
        startPlaying(id: ordered[pos])
    }

    /// 立即播放单曲：作为插播，不打乱原上下文（playSongNow）
    func playSongNow(_ song: Song) {
        skipVisited.removeAll()
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
        stepBackward()
    }

    /// 退回上下文前一首；撞到失效曲目时由 handleUnplayable(.backward) 继续向前找（design.md D3）
    private func stepBackward() {
        if ctx.pos > 0 {
            ctx.pos -= 1
            isManual = false
            startPlaying(id: ctx.ids[ctx.pos], skipOnMissing: .backward)
        } else {
            // 已在第一首，前面再无可用曲目：停在当前曲首
            if currentId != nil { seek(to: 0) } else { stopPlayback() }
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

    func resetPlaybackSession() {
        stopPlayback()
        playToken += 1
        manualQueue = []
        ctx = Context()
        isManual = false
        skipVisited.removeAll()
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

    private func startPlaying(id: String, skipOnMissing: SkipDirection = .forward) {
        guard let song = songProvider(id) else { return }
        engine?.stop()
        engine = nil
        progress = 0
        currentId = id
        playToken += 1
        let token = playToken

        if let url = song.fileURL {
            // 真实文件：文件不存在直接按方向跳过
            guard FileManager.default.fileExists(atPath: url.path) else {
                handleUnplayable(song: song, direction: skipOnMissing)
                return
            }
            // 构造解码引擎放到后台，避免大文件/网络卷阻塞 UI（design.md D5）
            isPlaying = false
            let vol = volume
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let made = try? AVAudioPlayerEngine(url: url, volume: vol)
                DispatchQueue.main.async {
                    guard let self, self.playToken == token else { return } // 用户已切歌，作废
                    guard let e = made else {
                        self.handleUnplayable(song: song, direction: skipOnMissing)
                        return
                    }
                    self.attachAndPlay(e)
                }
            }
        } else {
            // 示例曲目：模拟进度，无 IO，直接接管
            attachAndPlay(SimulatedEngine(duration: song.duration))
        }
    }

    /// 成功取得引擎后接管播放，并清空本轮跳过记录
    private func attachAndPlay(_ e: PlaybackEngine) {
        skipVisited.removeAll()
        engine = e
        e.onFinished = { [weak self] in self?.handleFinished() }
        e.play()
        isPlaying = true
        startProgressTimer()
    }

    /// 文件缺失或无法解码：标记失效、提示并按方向继续寻找可用曲目；绕回一圈则停止（design.md D3/D4）
    private func handleUnplayable(song: Song, direction: SkipDirection) {
        onMissing(song.id)
        isPlaying = false
        if skipVisited.contains(song.id) {
            // 候选重复出现，全库不可播
            skipVisited.removeAll()
            onToast("没有可播放的曲目")
            stopPlayback()
            return
        }
        skipVisited.insert(song.id)
        onToast("「\(song.title)」的文件不可用，已跳过")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch direction {
            case .forward: self.next()
            case .backward: self.stepBackward()
            }
        }
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
