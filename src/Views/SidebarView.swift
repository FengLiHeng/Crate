import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(AppState.self) private var app
    @State private var showingGroupEditor = false
    @State private var editingGroup: Playlist?
    @State private var pendingDeleteGroup: Playlist?
    @State private var draggedGroupId: String?
    @State private var groupDragReleaseMonitor = MouseDragReleaseMonitor()
    @State private var groupName = ""
    @State private var songDropTargetGroupId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 原生交通灯悬浮于左上角，预留空间（player.css .traffic）
            Spacer().frame(height: 40)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    sectionHeader("资料库")
                    SideItem(
                        icon: "music.note",
                        label: "歌曲",
                        active: app.view == .library
                    ) { app.view = .library }

                    sectionHeader("分组", showsAddButton: true)
                    ForEach(Array(app.playlists.enumerated()), id: \.element.id) { index, pl in
                        SidebarGroupRow(
                            playlist: pl,
                            targetIndex: index,
                            active: app.view == .playlist(pl.id),
                            isSystemGroup: app.isSystemGroup(pl),
                            isDragging: draggedGroupId == pl.id,
                            draggedGroupId: $draggedGroupId,
                            songDropTargetGroupId: $songDropTargetGroupId,
                            onSelect: {
                                app.view = .playlist(pl.id)
                            },
                            onRename: {
                                editingGroup = pl
                                groupName = pl.name
                                showingGroupEditor = true
                            },
                            onDelete: {
                                pendingDeleteGroup = pl
                            },
                            onBeginDrag: {
                                beginGroupDragging(pl.id)
                            },
                            onFinishGroupDrag: finishGroupDragging,
                            onMoveGroup: moveDraggedGroup,
                            onSongDrop: { providers in
                                acceptSongDrop(providers, into: pl)
                            }
                        )
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 224)
        .background(app.tokens.sidebarBg)
        .overlay(alignment: .trailing) {
            Rectangle().fill(app.tokens.sep).frame(width: 1)
        }
        .sheet(isPresented: $showingGroupEditor) {
            GroupNameSheet(
                title: editingGroup == nil ? "新建分组" : "重命名分组",
                confirmTitle: editingGroup == nil ? "创建" : "保存",
                name: $groupName,
                error: app.groupNameError(groupName, excluding: editingGroup?.id)
            ) {
                let committed: Bool
                if let editingGroup {
                    committed = app.renameGroup(editingGroup.id, to: groupName)
                } else {
                    committed = app.createGroup(named: groupName) != nil
                }
                guard committed else { return }
                groupName = ""
                editingGroup = nil
                showingGroupEditor = false
            } onCancel: {
                groupName = ""
                editingGroup = nil
                showingGroupEditor = false
            }
        }
        .alert("删除分组？", isPresented: deleteConfirmation) {
            Button("取消", role: .cancel) { pendingDeleteGroup = nil }
            Button("删除", role: .destructive) {
                if let pendingDeleteGroup {
                    app.deleteGroup(pendingDeleteGroup.id)
                }
                pendingDeleteGroup = nil
            }
        } message: {
            Text("这只会删除分组，不会删除资料库中的歌曲。")
        }
        .onDisappear {
            finishGroupDragging()
        }
    }

    private func sectionHeader(_ title: String, showsAddButton: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(app.tokens.text3)
            Spacer(minLength: 0)
            if showsAddButton {
                IconButton(systemName: "plus", size: 10, side: 20, help: "新建分组") {
                    groupName = ""
                    editingGroup = nil
                    showingGroupEditor = true
                }
            }
        }
        .padding(.init(top: 16, leading: 20, bottom: 6, trailing: showsAddButton ? 14 : 20))
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingDeleteGroup != nil },
            set: { if !$0 { pendingDeleteGroup = nil } }
        )
    }

    private func beginGroupDragging(_ groupId: String) -> NSItemProvider {
        finishGroupDragging()
        draggedGroupId = groupId
        groupDragReleaseMonitor.start {
            finishGroupDragging()
        }
        return NSItemProvider(object: groupId as NSString)
    }

    private func finishGroupDragging() {
        draggedGroupId = nil
        groupDragReleaseMonitor.stop()
    }

    private func moveDraggedGroup(_ sourceGroupId: String, to targetIndex: Int) {
        withAnimation(MotionTokens.feedback) {
            app.moveGroup(sourceGroupId, to: targetIndex)
        }
    }

    private func acceptSongDrop(_ providers: [NSItemProvider], into playlist: Playlist) -> Bool {
        guard !app.isSystemGroup(playlist),
              let provider = providers.first(where: {
                  $0.hasItemConformingToTypeIdentifier(SongDragPayload.typeIdentifier)
              }) else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: SongDragPayload.typeIdentifier) { data, _ in
            guard let data,
                  let songIds = try? JSONDecoder().decode([String].self, from: data) else { return }
            Task { @MainActor in
                app.addSongs(songIds, toGroupId: playlist.id)
                songDropTargetGroupId = nil
            }
        }
        return true
    }
}

private struct SidebarGroupRow: View {
    var playlist: Playlist
    var targetIndex: Int
    var active: Bool
    var isSystemGroup: Bool
    var isDragging: Bool
    @Binding var draggedGroupId: String?
    @Binding var songDropTargetGroupId: String?
    var onSelect: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void
    var onBeginDrag: () -> NSItemProvider
    var onFinishGroupDrag: () -> Void
    var onMoveGroup: (String, Int) -> Void
    var onSongDrop: ([NSItemProvider]) -> Bool

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        if isSystemGroup {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
            .onHover { hovering = $0 }
        } else {
            Button(action: onSelect) {
                rowContent
                    .onDrag(onBeginDrag) {
                        SidebarGroupDragPreview(playlist: playlist)
                            .environment(app)
                    }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("重命名", action: onRename)
                Button("删除分组", role: .destructive, action: onDelete)
            }
            .onDrop(
                of: [PlaylistDragPayload.contentType, SongDragPayload.contentType],
                delegate: SidebarGroupDropDelegate(
                    targetGroupId: playlist.id,
                    targetIndex: targetIndex,
                    draggedGroupId: $draggedGroupId,
                    songDropTargetGroupId: $songDropTargetGroupId,
                    onFinishGroupDrag: onFinishGroupDrag,
                    onMoveGroup: onMoveGroup,
                    onSongDrop: onSongDrop
                )
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
            .onHover { hovering = $0 }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(app.tokens.accent)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(playlist.name)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? app.tokens.accent : app.tokens.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            if !isSystemGroup {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(app.tokens.text3)
                    .opacity(hovering || isDragging ? 0.9 : 0.55)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? app.tokens.accentSoft : (hovering ? app.tokens.hover : .clear))
        }
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(app.tokens.accent)
                .frame(width: 3, height: active ? 18 : 0)
                .padding(.leading, 3)
                .opacity(active ? 1 : 0)
        }
        .overlay {
            if songDropTargetGroupId == playlist.id {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(app.tokens.accent, lineWidth: 1.5)
            }
        }
        .opacity(isDragging ? 0 : 1)
        .overlay {
            if isDragging {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(app.tokens.accentSoft)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                app.tokens.accent.opacity(0.72),
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .animation(MotionTokens.feedback, value: hovering)
        .animation(MotionTokens.feedback, value: active)
        .animation(MotionTokens.feedback, value: isDragging)
    }
}

private struct SidebarGroupDragPreview: View {
    var playlist: Playlist

    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(app.tokens.accent)
                .frame(width: 16)
            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(app.tokens.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(app.tokens.text3)
        }
        .padding(.horizontal, 10)
        .frame(width: 184, height: 34)
        .background(app.tokens.panelBg)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(app.tokens.sep, lineWidth: 1)
        }
        .shadow(color: .black.opacity(app.theme == .dark ? 0.28 : 0.16), radius: 7, y: 3)
    }
}

private struct SidebarGroupDropDelegate: DropDelegate {
    var targetGroupId: String
    var targetIndex: Int
    @Binding var draggedGroupId: String?
    @Binding var songDropTargetGroupId: String?
    var onFinishGroupDrag: () -> Void
    var onMoveGroup: (String, Int) -> Void
    var onSongDrop: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        if isGroupDrag(info) {
            return true
        }
        return info.hasItemsConforming(to: [SongDragPayload.typeIdentifier])
    }

    func dropEntered(info: DropInfo) {
        if isGroupDrag(info) {
            guard let draggedGroupId,
                  draggedGroupId != targetGroupId else { return }
            onMoveGroup(draggedGroupId, targetIndex)
        } else if info.hasItemsConforming(to: [SongDragPayload.typeIdentifier]) {
            songDropTargetGroupId = targetGroupId
        }
    }

    func dropExited(info: DropInfo) {
        if songDropTargetGroupId == targetGroupId {
            songDropTargetGroupId = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            return DropProposal(operation: .cancel)
        }
        return DropProposal(operation: isGroupDrag(info) ? .move : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        if isGroupDrag(info) {
            onFinishGroupDrag()
            return true
        }
        let providers = info.itemProviders(for: [SongDragPayload.typeIdentifier])
        let accepted = onSongDrop(providers)
        songDropTargetGroupId = nil
        return accepted
    }

    private func isGroupDrag(_ info: DropInfo) -> Bool {
        draggedGroupId != nil
            && info.hasItemsConforming(to: [PlaylistDragPayload.typeIdentifier])
    }
}

private struct GroupNameSheet: View {
    var title: String
    var confirmTitle: String
    @Binding var name: String
    var error: String?
    var onCommit: () -> Void
    var onCancel: () -> Void

    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool
    @State private var hasEdited = false

    private var canCreate: Bool {
        error == nil
    }

    private var visibleError: String? {
        hasEdited ? error : nil
    }

    private var nameCount: Int {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: titleIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(app.tokens.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(app.tokens.accentSoft)
                        )

                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(app.tokens.text)
                }

                VStack(alignment: .leading, spacing: 7) {
                    TextField("输入分组名称", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(app.tokens.text)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(app.tokens.ctrl)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(inputBorderColor, lineWidth: focused ? 1.2 : 0.8)
                        )
                        .focused($focused)
                        .onChange(of: name) { _, _ in hasEdited = true }
                        .onSubmit {
                            hasEdited = true
                            if canCreate { onCommit() }
                        }

                    HStack(spacing: 8) {
                        if let visibleError {
                            Label(visibleError, systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 11.5))
                                .foregroundStyle(app.tokens.danger)
                                .lineLimit(1)
                                .labelStyle(.titleAndIcon)
                        }
                        Spacer(minLength: 0)
                        Text("\(nameCount)/\(GroupNameValidation.maxLength)")
                            .font(.system(size: 11.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(nameCount > GroupNameValidation.maxLength ? app.tokens.danger : app.tokens.text3)
                    }
                    .frame(minHeight: 18)
                }
            }
            .padding(.init(top: 22, leading: 22, bottom: 18, trailing: 22))

            HStack(spacing: 10) {
                Spacer()
                Button("取消", action: onCancel)
                Button(action: {
                    hasEdited = true
                    onCommit()
                }) {
                    Text(confirmTitle)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
            .padding(.init(top: 14, leading: 22, bottom: 18, trailing: 22))
            .background(app.tokens.panelBg)
            .overlay(alignment: .top) {
                Rectangle().fill(app.tokens.sep).frame(height: 1)
            }
        }
        .frame(width: 360)
        .background(app.tokens.winBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { focused = true }
    }

    private var titleIcon: String {
        confirmTitle == "创建" ? "folder.badge.plus" : "pencil"
    }

    private var inputBorderColor: Color {
        if visibleError != nil { return app.tokens.danger }
        return focused ? app.tokens.accent : app.tokens.sep
    }
}

private struct SideItem: View {
    var icon: String
    var label: String
    var active: Bool
    var action: () -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .onHover { hovering = $0 }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(app.tokens.accent)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? app.tokens.accent : app.tokens.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? app.tokens.accentSoft : (hovering ? app.tokens.hover : .clear))
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(app.tokens.accent)
                .frame(width: 3, height: active ? 18 : 0)
                .padding(.leading, 3)
                .opacity(active ? 1 : 0)
        }
        .scaleEffect(hovering && !active ? 1.006 : 1)
        .contentShape(Rectangle())
        .animation(MotionTokens.feedback, value: hovering)
        .animation(MotionTokens.feedback, value: active)
    }
}
