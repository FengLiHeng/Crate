import AppKit
import SwiftUI
import UniformTypeIdentifiers

// 待播清单面板（player.css .queue-panel / player-views.jsx QueuePanel）
struct QueuePanelView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggedItem: QueueDragItem?
    @State private var dragReleaseMonitor = MouseDragReleaseMonitor()

    var body: some View {
        let manualIds = app.player.manualQueue
        let contextIds = app.player.ctx.ids
        let upcomingStart = min(app.player.ctx.pos + 1, contextIds.count)
        let upcomingIndices = upcomingStart..<contextIds.count
        let indexedManualIds = Array(manualIds.enumerated())
        let indexedUpcomingIds = Array(contextIds[upcomingIndices].enumerated())
        let hasUpcoming = !manualIds.isEmpty || !upcomingIndices.isEmpty

        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("待播清单")
                    .font(.headline)
                    .foregroundStyle(app.tokens.text)
                Spacer()
                if hasUpcoming {
                    Button("清空") {
                        withAnimation(MotionTokens.list(reduceMotion: reduceMotion)) {
                            app.player.clearQueue()
                        }
                    }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(app.tokens.accent)
                }
                IconButton(systemName: "xmark", size: 11, side: 24, help: "关闭") {
                    withAnimation(MotionTokens.panel(reduceMotion: reduceMotion)) { app.closeQueue() }
                }
            }
            .padding(.init(top: 16, leading: 18, bottom: 10, trailing: 14))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let current = app.player.currentSong {
                        sectionLabel("正在播放")
                        QueueRow(song: current, isCurrent: true)

                        if hasUpcoming {
                            sectionLabel("接下来")
                        }
                        if !manualIds.isEmpty {
                            ForEach(indexedManualIds, id: \.element) { index, id in
                                if let song = app.songsById[id] {
                                    QueueRow(
                                        song: song,
                                        isCurrent: false,
                                        isRecentlyPrioritized: manualIds.first == id
                                            && app.player.recentlyPrioritizedId == id,
                                        removable: true,
                                        reorderable: true,
                                        isDragging: draggedItem == QueueDragItem(section: .manual, songId: id),
                                        onPlay: {
                                            guard let currentIndex = app.player.manualQueue.firstIndex(of: id) else { return }
                                            app.player.playManualAt(currentIndex)
                                        },
                                        onRemove: {
                                            withAnimation(MotionTokens.list(reduceMotion: reduceMotion)) {
                                                guard let currentIndex = app.player.manualQueue.firstIndex(of: id) else { return }
                                                app.player.removeManualAt(currentIndex)
                                            }
                                        },
                                        onMoveUp: index > 0 ? { moveManual(id, by: -1) } : nil,
                                        onMoveDown: index + 1 < manualIds.count ? { moveManual(id, by: 1) } : nil
                                    )
                                    .onDrag {
                                        beginDragging(QueueDragItem(section: .manual, songId: id))
                                    } preview: {
                                        QueueDragPreview(song: song)
                                            .environment(app)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: QueueReorderDropDelegate(
                                            target: QueueDragItem(section: .manual, songId: id),
                                            draggedItem: $draggedItem,
                                            onMove: moveDraggedItem
                                        )
                                    )
                                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                                }
                            }
                        }
                        if !upcomingIndices.isEmpty {
                            ForEach(indexedUpcomingIds, id: \.element) { index, id in
                                if let song = app.songsById[id] {
                                    QueueRow(
                                        song: song,
                                        isCurrent: false,
                                        reorderable: true,
                                        isDragging: draggedItem == QueueDragItem(section: .upcoming, songId: id),
                                        onPlay: {
                                            guard let currentIndex = app.player.upcomingIds.firstIndex(of: id) else { return }
                                            app.player.playContextAt(currentIndex)
                                        },
                                        onMoveUp: index > 0 ? { moveUpcoming(id, by: -1) } : nil,
                                        onMoveDown: index + 1 < upcomingIndices.count ? { moveUpcoming(id, by: 1) } : nil
                                    )
                                    .onDrag {
                                        beginDragging(QueueDragItem(section: .upcoming, songId: id))
                                    } preview: {
                                        QueueDragPreview(song: song)
                                            .environment(app)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: QueueReorderDropDelegate(
                                            target: QueueDragItem(section: .upcoming, songId: id),
                                            draggedItem: $draggedItem,
                                            onMove: moveDraggedItem
                                        )
                                    )
                                    .transition(.opacity)
                                }
                            }
                        }
                        if !hasUpcoming {
                            EmptyHint(text: "队列中暂无后续歌曲\n在歌曲上右键选择「下一首播放」试试", small: true)
                        }
                    } else {
                        EmptyHint(text: "当前没有播放内容")
                    }
                }
                .padding(.init(top: 0, leading: 10, bottom: 16, trailing: 10))
                .animation(MotionTokens.list(reduceMotion: reduceMotion), value: manualIds)
                .animation(MotionTokens.list(reduceMotion: reduceMotion), value: contextIds)
                .animation(MotionTokens.list(reduceMotion: reduceMotion), value: app.player.currentId)
            }
        }
        .frame(width: 300)
        .background(app.tokens.panelBg)
        .overlay(alignment: .leading) {
            Rectangle().fill(app.tokens.sep).frame(width: 1)
        }
        .shadow(
            color: .black.opacity(app.theme == .dark ? 0.12 : 0.075),
            radius: app.theme == .dark ? 16 : 12,
            x: -5
        )
        .onDisappear {
            finishDragging()
        }
    }

    private func beginDragging(_ item: QueueDragItem) -> NSItemProvider {
        finishDragging()
        draggedItem = item
        dragReleaseMonitor.start {
            finishDragging()
        }
        return NSItemProvider(object: item.songId as NSString)
    }

    private func finishDragging() {
        draggedItem = nil
        dragReleaseMonitor.stop()
    }

    private func moveManual(_ songId: String, by offset: Int) {
        guard let sourceIndex = app.player.manualQueue.firstIndex(of: songId) else { return }
        withAnimation(MotionTokens.list(reduceMotion: reduceMotion)) {
            _ = app.player.moveManualQueueItem(from: sourceIndex, to: sourceIndex + offset)
        }
    }

    private func moveUpcoming(_ songId: String, by offset: Int) {
        guard let sourceIndex = app.player.upcomingIds.firstIndex(of: songId) else { return }
        withAnimation(MotionTokens.list(reduceMotion: reduceMotion)) {
            _ = app.player.moveUpcomingItem(from: sourceIndex, to: sourceIndex + offset)
        }
    }

    private func moveDraggedItem(_ source: QueueDragItem, _ target: QueueDragItem) {
        guard source.section == target.section else { return }
        withAnimation(MotionTokens.list(reduceMotion: reduceMotion)) {
            switch source.section {
            case .manual:
                guard let sourceIndex = app.player.manualQueue.firstIndex(of: source.songId),
                      let destinationIndex = app.player.manualQueue.firstIndex(of: target.songId) else { return }
                app.player.moveManualQueueItem(from: sourceIndex, to: destinationIndex)
            case .upcoming:
                let ids = app.player.upcomingIds
                guard let sourceIndex = ids.firstIndex(of: source.songId),
                      let destinationIndex = ids.firstIndex(of: target.songId) else { return }
                app.player.moveUpcomingItem(from: sourceIndex, to: destinationIndex)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .kerning(0.55)
            .foregroundStyle(app.tokens.text3)
            .padding(.init(top: 14, leading: 8, bottom: 6, trailing: 8))
    }
}

private struct QueueRow: View {
    var song: Song
    var isCurrent: Bool
    var isRecentlyPrioritized = false
    var removable = false
    var reorderable = false
    var isDragging = false
    var onPlay: (() -> Void)?
    var onRemove: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let album = song.albumId.flatMap { app.albumsById[$0] }
        HStack(spacing: 10) {
            CoverView(song: song, album: album, size: 34, radius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isCurrent ? app.tokens.accent : app.tokens.text)
                    .lineLimit(1)
                Text(app.artistName(for: song))
                    .font(.caption)
                    .foregroundStyle(app.tokens.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isCurrent {
                EqBars(paused: !app.player.isPlaying, accent: app.tokens.accent)
            } else {
                if reorderable {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(app.tokens.text3)
                        .frame(width: 20, height: 22)
                        .contentShape(Rectangle())
                        .help("拖动调整播放顺序")
                        .accessibilityHidden(true)
                }
                if removable {
                    IconButton(systemName: "xmark", size: 10, side: 22, help: "从队列移除") {
                        onRemove?()
                    }
                    .opacity(hovering ? 1 : 0.45)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isRecentlyPrioritized
                        ? app.tokens.accentSoft
                        : (hovering && !isCurrent ? app.tokens.hover : .clear)
                )
        )
        .overlay {
            if isRecentlyPrioritized {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(app.tokens.accent.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(
            (hovering && !isCurrent || isRecentlyPrioritized) && !reduceMotion
                ? 1.006
                : 1
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .gesture(TapGesture(count: 2).onEnded { onPlay?() })
        .modifier(
            QueueRowAccessibilityActions(
                onPlay: onPlay,
                onRemove: onRemove,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown
            )
        )
        .opacity(isDragging ? 0 : 1)
        .overlay {
            if isDragging {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(app.tokens.accentSoft)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                app.tokens.accent.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                    }
                    .padding(.vertical, 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(MotionTokens.feedback, value: hovering)
        .animation(MotionTokens.feedback, value: isCurrent)
        .animation(MotionTokens.feedback, value: isRecentlyPrioritized)
        .animation(MotionTokens.feedback, value: isDragging)
    }
}

private struct QueueDragPreview: View {
    var song: Song

    @Environment(AppState.self) private var app

    var body: some View {
        let album = song.albumId.flatMap { app.albumsById[$0] }

        HStack(spacing: 10) {
            CoverView(song: song, album: album, size: 34, radius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(app.tokens.text)
                    .lineLimit(1)
                Text(app.artistName(for: song))
                    .font(.caption)
                    .foregroundStyle(app.tokens.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(app.tokens.text3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 232, alignment: .leading)
        .background(app.tokens.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(app.tokens.sep, lineWidth: 1)
        }
        .shadow(color: .black.opacity(app.theme == .dark ? 0.28 : 0.16), radius: 8, y: 3)
    }
}

private struct QueueRowAccessibilityActions: ViewModifier {
    var onPlay: (() -> Void)?
    var onRemove: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        baseContent(content)
            .modifier(OptionalAccessibilityAction(name: "上移", action: onMoveUp))
            .modifier(OptionalAccessibilityAction(name: "下移", action: onMoveDown))
    }

    @ViewBuilder
    private func baseContent(_ content: Content) -> some View {
        if let onPlay, let onRemove {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("播放")) { onPlay() }
                .accessibilityAction(named: Text("从队列移除")) { onRemove() }
        } else if let onPlay {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("播放")) { onPlay() }
        } else if let onRemove {
            content
                .accessibilityAction(named: Text("从队列移除")) { onRemove() }
        } else {
            content
        }
    }
}

private struct OptionalAccessibilityAction: ViewModifier {
    var name: String
    var action: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Text(name), action)
        } else {
            content
        }
    }
}

private enum QueueSection: Equatable {
    case manual
    case upcoming
}

private struct QueueDragItem: Equatable {
    var section: QueueSection
    var songId: String
}

private struct QueueReorderDropDelegate: DropDelegate {
    var target: QueueDragItem
    @Binding var draggedItem: QueueDragItem?
    var onMove: (QueueDragItem, QueueDragItem) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItem?.section == target.section
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem.section == target.section,
              draggedItem.songId != target.songId else { return }
        onMove(draggedItem, target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: validateDrop(info: info) ? .move : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        let accepted = validateDrop(info: info)
        draggedItem = nil
        return accepted
    }
}
