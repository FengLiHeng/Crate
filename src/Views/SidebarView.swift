import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var app
    @State private var showingGroupEditor = false
    @State private var editingGroup: Playlist?
    @State private var pendingDeleteGroup: Playlist?
    @State private var draggedGroupId: String?
    @State private var dragStartIndex: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var groupName = ""

    private let groupRowHeight: CGFloat = 32

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
                        SideItem(
                            icon: "music.note.list",
                            label: pl.name,
                            active: app.view == .playlist(pl.id)
                        ) { app.view = .playlist(pl.id) }
                        .contextMenu {
                            if !app.isSystemGroup(pl) {
                                Button("重命名") {
                                    editingGroup = pl
                                    groupName = pl.name
                                    showingGroupEditor = true
                                }
                                Button("删除分组", role: .destructive) {
                                    pendingDeleteGroup = pl
                                }
                            }
                        }
                        .offset(y: rowOffset(for: pl.id, at: index))
                        .scaleEffect(draggedGroupId == pl.id ? 1.015 : 1)
                        .zIndex(draggedGroupId == pl.id ? 1 : 0)
                        .animation(draggedGroupId == pl.id ? nil : .easeOut(duration: 0.12), value: dragTargetIndex)
                        .gesture(groupDragGesture(for: pl.id, at: index))
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

    private var dragTargetIndex: Int? {
        guard let dragStartIndex, !app.playlists.isEmpty else { return nil }
        let delta = Int((dragTranslation / groupRowHeight).rounded())
        return Swift.min(Swift.max(dragStartIndex + delta, 1), app.playlists.count - 1)
    }

    private func rowOffset(for groupId: String, at index: Int) -> CGFloat {
        guard let draggedGroupId,
              let dragStartIndex,
              let dragTargetIndex else { return 0 }
        if groupId == draggedGroupId { return dragTranslation }
        if dragStartIndex < dragTargetIndex, index > dragStartIndex, index <= dragTargetIndex {
            return -groupRowHeight
        }
        if dragTargetIndex < dragStartIndex, index >= dragTargetIndex, index < dragStartIndex {
            return groupRowHeight
        }
        return 0
    }

    private func groupDragGesture(for groupId: String, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard !isSystemGroup(groupId) else { return }
                if draggedGroupId == nil {
                    draggedGroupId = groupId
                    dragStartIndex = index
                }
                guard draggedGroupId == groupId else { return }
                dragTranslation = value.translation.height
            }
            .onEnded { _ in
                if draggedGroupId == groupId,
                   let dragStartIndex,
                   let dragTargetIndex,
                   dragTargetIndex != dragStartIndex {
                    app.moveGroup(groupId, to: dragTargetIndex)
                }
                resetGroupDrag()
            }
    }

    private func isSystemGroup(_ groupId: String) -> Bool {
        app.playlists.first(where: { $0.id == groupId }).map(app.isSystemGroup) ?? false
    }

    private func resetGroupDrag() {
        draggedGroupId = nil
        dragStartIndex = nil
        dragTranslation = 0
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

    private var canCreate: Bool {
        error == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(app.tokens.text)
            TextField("分组名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    if canCreate { onCommit() }
                }
            Text(error ?? "1-\(GroupNameValidation.maxLength) 个字符，可用中英文、数字、空格和 - _ · & + # ()")
                .font(.system(size: 11.5))
                .foregroundStyle(error == nil ? app.tokens.text3 : app.tokens.danger)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Spacer()
                Button("取消", action: onCancel)
                Button(confirmTitle, action: onCommit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(app.tokens.winBg)
        .onAppear { focused = true }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}
