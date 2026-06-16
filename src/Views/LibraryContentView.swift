import SwiftUI
import AppKit

struct LibraryContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ContentHeader()
            Rectangle().fill(app.tokens.sep).frame(height: 1)
            SongTableView()
        }
        .background(app.tokens.winBg)
    }
}

// MARK: - 内容区头部（player.css .content-head）

private struct ContentHeader: View {
    @Environment(AppState.self) private var app
    @State private var confirmClearLibrary = false

    var body: some View {
        @Bindable var app = app
        let songs = app.viewSongs
        let playbackSongs = app.viewPlaybackSongs

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
                            .font(.system(size: 24, weight: .bold))
                            .kerning(-0.3)
                            .foregroundStyle(app.tokens.text)
                        Text("\(songs.count) 首歌曲")
                            .font(.system(size: 12.5))
                            .foregroundStyle(app.tokens.text2)
                    }
                }

                Spacer()

                // 工具组：搜索 / 导入 / 主题
                HStack(spacing: 8) {
                    SearchField(text: $app.search)
                    if !app.missingIds.isEmpty {
                        ToolButton(systemName: "exclamationmark.triangle", help: "清理失效曲目") {
                            app.cleanupMissing()
                        }
                    }
                    ToolButton(systemName: "trash", help: "清空歌曲列表", disabled: app.library.isEmpty) {
                        confirmClearLibrary = true
                    }
                    ImportMenuButton()
                    ToolButton(
                        systemName: app.theme == .light ? "moon" : "sun.max",
                        help: app.theme == .light ? "切换深色模式" : "切换浅色模式"
                    ) {
                        app.theme = app.theme == .light ? .dark : .light
                    }
                }
            }

            // 播放 / 随机播放
            HStack(spacing: 10) {
                CapsuleButton(icon: "play.fill", label: "播放", primary: true, disabled: playbackSongs.isEmpty) {
                    app.player.playFrom(playbackSongs, index: 0)
                }
                CapsuleButton(icon: "shuffle", label: "随机播放", primary: false, disabled: playbackSongs.isEmpty) {
                    app.player.playFrom(playbackSongs, index: -1, forceShuffle: true)
                }
            }
            .padding(.top, 14)
        }
        .padding(.init(top: 16, leading: 24, bottom: 12, trailing: 24))
        .alert("清空歌曲列表？", isPresented: $confirmClearLibrary) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                app.clearLibrary()
            }
        } message: {
            Text("这会移除列表中的所有歌曲并清空待播清单，但不会删除磁盘上的音频文件。")
        }
    }
}

// MARK: - 搜索框（player.css .search-field）

private struct SearchField: View {
    @Binding var text: String
    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool

    var body: some View {
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
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(app.tokens.text2)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 200, height: 32)
        .background(app.tokens.ctrl, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 工具按钮（player.css .tool-btn）

private struct ToolButton: View {
    var systemName: String
    var help: String
    var disabled = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ToolButtonChrome(systemName: systemName, hovering: hovering, disabled: disabled)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .help(help)
    }
}

private struct ImportMenuButton: View {
    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Button {
            ImportMenuActionTarget(
                importFiles: { app.importViaPanel() },
                importFolder: { app.importFolderViaPanel() }
            ).show()
        } label: {
            ToolButtonChrome(systemName: "plus", hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("导入音乐")
    }
}

private final class ImportMenuActionTarget: NSObject, NSMenuDelegate {
    private static var retainedTargets: [ImportMenuActionTarget] = []

    private let importFiles: () -> Void
    private let importFolder: () -> Void

    init(importFiles: @escaping () -> Void, importFolder: @escaping () -> Void) {
        self.importFiles = importFiles
        self.importFolder = importFolder
    }

    func show() {
        let menu = NSMenu()
        menu.delegate = self

        let fileItem = NSMenuItem(title: "导入文件", action: #selector(importFilesAction), keyEquivalent: "")
        fileItem.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
        fileItem.target = self
        menu.addItem(fileItem)

        let folderItem = NSMenuItem(title: "导入文件夹", action: #selector(importFolderAction), keyEquivalent: "")
        folderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        folderItem.target = self
        menu.addItem(folderItem)

        Self.retainedTargets.append(self)

        if let event = NSApp.currentEvent, let view = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc private func importFilesAction() {
        importFiles()
    }

    @objc private func importFolderAction() {
        importFolder()
    }

    func menuDidClose(_ menu: NSMenu) {
        Self.retainedTargets.removeAll { $0 === self }
    }
}

private struct ToolButtonChrome: View {
    var systemName: String
    var hovering: Bool
    var disabled = false

    @Environment(AppState.self) private var app

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(hovering && !disabled ? app.tokens.text : app.tokens.text2)
            .frame(width: 32, height: 32)
            .background(app.tokens.ctrl, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hovering && !disabled ? app.tokens.hover : .clear)
            )
    }
}

// MARK: - 主操作按钮（player.css .btn / .btn-primary）

private struct CapsuleButton: View {
    var icon: String
    var label: String
    var primary: Bool
    var disabled: Bool
    var action: () -> Void

    @Environment(AppState.self) private var app
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(primary ? app.tokens.accentFg : app.tokens.text)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(primary ? app.tokens.accent : app.tokens.ctrl)
            )
            .brightness(hovering && !disabled ? (primary ? 0.06 : -0.03) : 0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hovering = $0 }
    }
}
