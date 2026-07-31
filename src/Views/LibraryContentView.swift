import SwiftUI

struct LibraryContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ContentHeader()
            Rectangle().fill(app.tokens.sep).frame(height: 1)
            SongTableView()
        }
        .background(app.tokens.winBg)
        .alert(
            pendingRemovalTitle,
            isPresented: Binding(
                get: { app.pendingSongRemoval != nil },
                set: { if !$0 { app.cancelPendingSongRemoval() } }
            )
        ) {
            Button("取消", role: .cancel) { app.cancelPendingSongRemoval() }
            Button("移除", role: .destructive) { app.confirmPendingSongRemoval() }
        } message: {
            Text(pendingRemovalMessage)
        }
    }

    private var pendingRemovalTitle: String {
        guard let pending = app.pendingSongRemoval else { return "移除歌曲？" }
        return "移除 \(pending.songIds.count) 首歌曲？"
    }

    private var pendingRemovalMessage: String {
        guard let pending = app.pendingSongRemoval else { return "" }
        switch pending.scope {
        case .library:
            return "所选歌曲会从资料库、全部分组和待播引用中移除，但不会删除磁盘上的音频文件。"
        case .playlist(_, let name):
            return "所选歌曲只会从分组「\(name)」移除，资料库、磁盘文件和待播清单保持不变。"
        }
    }
}

// MARK: - 内容区头部（player.css .content-head）

private struct ContentHeader: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmClearLibrary = false
    @State private var showingMusicFolders = false

    var body: some View {
        @Bindable var app = app
        let songs = app.viewSongs

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // 标题区（分组视图带封面）
                HStack(spacing: 14) {
                    if let pl = app.viewPlaylist {
                        PlaylistCoverView(
                            playlist: pl,
                            albumsById: app.albumsById,
                            songsById: app.songsById,
                            size: 64, radius: 10
                        )
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.viewTitle)
                            .font(.title.bold())
                            .kerning(-0.3)
                            .foregroundStyle(app.tokens.text)
                        Text("\(songs.count) 首歌曲")
                            .font(.subheadline)
                            .foregroundStyle(app.tokens.text2)
                    }
                }

                Spacer()

                // 工具组：搜索 / 导入 / 主题
                HStack(spacing: 8) {
                    SearchField(text: $app.search)
                    SortMenuButton()
                    if app.selectedVisibleSongs.count > 1 {
                        BatchSelectionMenuButton()
                    }
                    if !app.missingIds.isEmpty {
                        ToolButton(
                            systemName: "exclamationmark.triangle",
                            help: "清理失效曲目",
                            disabled: app.importPhase.isImporting
                        ) {
                            app.cleanupMissing()
                        }
                    }
                    if app.importPhase.isImporting {
                        ImportProgressControl()
                    } else {
                        ImportFileButton()
                    }
                    ToolButton(
                        systemName: app.theme == .light ? "moon" : "sun.max",
                        help: app.theme == .light ? "切换深色模式" : "切换浅色模式"
                    ) {
                        withAnimation(MotionTokens.page(reduceMotion: reduceMotion)) {
                            app.theme = app.theme == .light ? .dark : .light
                        }
                    }
                    LibraryActionsMenuButton(
                        confirmClearLibrary: $confirmClearLibrary,
                        showingMusicFolders: $showingMusicFolders,
                        clearDisabled: app.library.isEmpty || app.importPhase.isImporting
                    )
                }
            }

        }
        .padding(.init(top: 16, leading: 24, bottom: 12, trailing: 24))
        .alert("清空歌曲列表？", isPresented: $confirmClearLibrary) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                app.clearLibrary()
            }
        } message: {
            Text("这会移除列表中的所有歌曲、音乐文件夹来源并清空待播清单，但不会删除磁盘上的音频文件。")
        }
        .sheet(isPresented: $showingMusicFolders) {
            MusicFoldersSheet()
        }
    }
}

private struct SortMenuButton: View {
    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Menu {
            ForEach(LibrarySortField.allCases) { field in
                Button {
                    if app.librarySortField == field {
                        app.toggleLibrarySortDirection()
                    } else {
                        app.librarySortField = field
                    }
                } label: {
                    if app.librarySortField == field {
                        Label(field.title, systemImage: "checkmark")
                    } else {
                        Text(field.title)
                    }
                }
            }
            Divider()
            Button {
                app.toggleLibrarySortDirection()
            } label: {
                Label(app.librarySortDirection.title, systemImage: app.librarySortDirection.systemImage)
            }
        } label: {
            ToolButtonChrome(
                systemName: "arrow.up.arrow.down",
                label: "排序",
                hovering: hovering
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("排序：\(app.librarySortField.title) · \(app.librarySortDirection.title)")
    }
}

private struct BatchSelectionMenuButton: View {
    @Environment(AppState.self) private var app
    @State private var hovering = false

    private var songs: [Song] { app.selectedVisibleSongs }
    private var songIds: [String] { songs.map(\.id) }
    private var addableGroups: [Playlist] {
        app.playlists.filter { group in
            !app.isSystemGroup(group)
                && app.viewPlaylist?.id != group.id
                && songIds.contains { !group.songIds.contains($0) }
        }
    }

    var body: some View {
        Menu {
            Button("收藏所选歌曲") {
                app.setFavorite(true, songIds: songIds)
            }
            Button("取消收藏所选歌曲") {
                app.setFavorite(false, songIds: songIds)
            }
            Button("加入待播清单") {
                app.addSongsToQueue(songIds)
            }
            if !addableGroups.isEmpty {
                Menu("添加到分组") {
                    ForEach(addableGroups) { group in
                        Button(group.name) {
                            app.addSongs(songIds, toGroupId: group.id)
                        }
                    }
                }
            }
            Divider()
            Button(app.viewPlaylist == nil ? "仅从资料库移除…" : "从此分组移除…", role: .destructive) {
                app.requestRemoval(of: songIds)
            }
            Divider()
            Button("取消选择") {
                app.clearSongSelection()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("\(songs.count) 首已选")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(app.tokens.accent)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering ? app.tokens.hover : app.tokens.accentSoft)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("批量操作")
    }
}

private struct ImportProgressControl: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(
                value: Double(app.importPhase.completed),
                total: Double(max(app.importPhase.total, 1))
            )
            .progressViewStyle(.linear)
            .frame(width: 88)
            .accessibilityLabel(app.libraryActivityKind == .scanning ? "扫描进度" : "导入进度")
            .accessibilityValue(app.libraryActivityMessage ?? app.libraryActivityKind.progressTitle)

            Text(app.libraryActivityMessage ?? app.libraryActivityKind.progressTitle)
                .font(.caption)
                .foregroundStyle(app.tokens.text2)
                .monospacedDigit()
                .accessibilityHidden(true)

            Button {
                app.cancelImport()
            } label: {
                Label("取消资料库任务", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(app.tokens.text2)
            }
            .buttonStyle(.plain)
            .help(app.libraryActivityKind == .scanning ? "取消扫描" : "取消导入")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(app.tokens.ctrl, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 搜索框（player.css .search-field）

private struct SearchField: View {
    @Binding var text: String
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        let clearTransition: AnyTransition = reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9))

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(app.tokens.text3)
            TextField("搜索", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(app.tokens.text)
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Label("清除搜索", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(app.tokens.text2)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .transition(clearTransition)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 200, height: 32)
        .background(app.tokens.ctrl, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(focused ? app.tokens.accent : app.tokens.sep, lineWidth: focused ? 1.1 : 0.7)
        }
        .animation(MotionTokens.feedback, value: text.isEmpty)
        .animation(MotionTokens.feedback, value: focused)
        .task {
            await Task.yield()
            focused = false
        }
    }
}

// MARK: - 工具按钮（player.css .tool-btn）

private struct ToolButton: View {
    var systemName: String
    var help: String
    var disabled = false
    var action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ToolButtonChrome(systemName: systemName, label: help, hovering: hovering, disabled: disabled)
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .help(help)
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

private struct LibraryActionsMenuButton: View {
    @Binding var confirmClearLibrary: Bool
    @Binding var showingMusicFolders: Bool
    var clearDisabled: Bool

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Menu {
            Button("音乐文件夹…") {
                showingMusicFolders = true
            }
            Button("重新扫描音乐文件夹") {
                app.scanMusicFolders()
            }
            .disabled(app.musicFolders.isEmpty || app.importPhase.isImporting)
            Divider()
            Button("清空歌曲列表", role: .destructive) {
                confirmClearLibrary = true
            }
            .disabled(clearDisabled)
        } label: {
            ToolButtonChrome(
                systemName: "ellipsis",
                label: "更多操作",
                hovering: hovering
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("更多操作")
        .accessibilityLabel("更多操作")
    }
}

private struct MusicFoldersSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundStyle(app.tokens.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("音乐文件夹")
                        .font(.title2.bold())
                        .foregroundStyle(app.tokens.text)
                    Text("Crate 会递归扫描这些位置，但不会复制或修改音乐文件。")
                        .font(.subheadline)
                        .foregroundStyle(app.tokens.text2)
                }
                Spacer()
            }
            .padding(20)

            Rectangle().fill(app.tokens.sep).frame(height: 1)

            if app.musicFolders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(app.tokens.text3)
                    Text("尚未添加音乐文件夹")
                        .font(.headline)
                        .foregroundStyle(app.tokens.text)
                    Text("添加后，重新扫描会同步其中新增、移动、修改或删除的歌曲。")
                        .font(.subheadline)
                        .foregroundStyle(app.tokens.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(app.musicFolders) { source in
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(app.tokens.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(source.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(app.tokens.text)
                                        .lineLimit(1)
                                    Text(source.path)
                                        .font(.caption)
                                        .foregroundStyle(app.tokens.text2)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    app.removeMusicFolder(source.id)
                                } label: {
                                    Label("移除音乐文件夹", systemImage: "minus.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(app.tokens.text2)
                                .disabled(app.importPhase.isImporting)
                                .help("停止同步并保留已导入歌曲")
                            }
                            .padding(12)
                            .background(app.tokens.ctrl, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(16)
                }
            }

            Rectangle().fill(app.tokens.sep).frame(height: 1)
            HStack {
                Button {
                    app.addMusicFoldersViaPanel()
                } label: {
                    Label("添加文件夹", systemImage: "plus")
                }
                .disabled(app.importPhase.isImporting)

                Button {
                    app.scanMusicFolders()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .disabled(app.musicFolders.isEmpty || app.importPhase.isImporting)

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 400)
        .background(app.tokens.winBg)
    }
}

private struct ImportFileButton: View {
    @Environment(AppState.self) private var app
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button {
            app.importViaPanel()
        } label: {
            ToolButtonChrome(systemName: "plus", label: "导入音乐文件", hovering: hovering)
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("导入音乐文件")
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

private struct ToolButtonChrome: View {
    var systemName: String
    var label: String
    var hovering: Bool
    var disabled = false

    @Environment(AppState.self) private var app

    var body: some View {
        Label(label, systemImage: systemName)
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(hovering && !disabled ? app.tokens.text : app.tokens.text2)
            .frame(width: 32, height: 32)
            .background(
                hovering && !disabled ? app.tokens.ctrl : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}
