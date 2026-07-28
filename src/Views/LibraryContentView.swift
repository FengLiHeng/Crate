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
                        ImportMenuButton()
                    }
                    ThemeMenuButton()
                    LibraryActionsMenuButton(
                        confirmClearLibrary: $confirmClearLibrary,
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
            Text("这会移除列表中的所有歌曲并清空待播清单，但不会删除磁盘上的音频文件。")
        }
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
            .accessibilityLabel("导入进度")
            .accessibilityValue(app.importPhase.message ?? "正在导入")

            Text(app.importPhase.message ?? "正在导入")
                .font(.caption)
                .foregroundStyle(app.tokens.text2)
                .monospacedDigit()
                .accessibilityHidden(true)

            Button {
                app.cancelImport()
            } label: {
                Label("取消导入", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(app.tokens.text2)
            }
            .buttonStyle(.plain)
            .help("取消导入")
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

private struct ThemeMenuButton: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private var help: String {
        "主题：\(app.themeMode.title)"
    }

    var body: some View {
        Menu {
            ForEach(AppThemeMode.allCases) { mode in
                Button {
                    guard mode != app.themeMode else { return }
                    withAnimation(MotionTokens.page(reduceMotion: reduceMotion)) {
                        app.themeMode = mode
                    }
                } label: {
                    if mode == app.themeMode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            ToolButtonChrome(
                systemName: app.themeMode.systemImage,
                label: help,
                hovering: hovering
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct LibraryActionsMenuButton: View {
    @Binding var confirmClearLibrary: Bool
    var clearDisabled: Bool

    @State private var hovering = false

    var body: some View {
        Menu {
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

private struct ImportMenuButton: View {
    @Environment(AppState.self) private var app
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button {
            ImportMenuActionTarget(
                importFiles: { app.importViaPanel() },
                importFolder: { app.importFolderViaPanel() }
            ).show()
        } label: {
            ToolButtonChrome(systemName: "plus", label: "导入音乐", hovering: hovering, emphasized: true)
                .scaleEffect(pressed ? 0.94 : 1)
                .animation(MotionTokens.feedback, value: hovering)
                .animation(MotionTokens.press, value: pressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("导入音乐")
        .pressEvents(onPress: { pressed = true }, onRelease: { pressed = false })
    }
}

@MainActor
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
    var label: String
    var hovering: Bool
    var disabled = false
    var emphasized = false

    @Environment(AppState.self) private var app

    var body: some View {
        Label(label, systemImage: systemName)
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(emphasized ? app.tokens.accent : (hovering && !disabled ? app.tokens.text : app.tokens.text2))
            .frame(width: 32, height: 32)
            .background(
                emphasized ? app.tokens.accentSoft : (hovering && !disabled ? app.tokens.ctrl : .clear),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}
