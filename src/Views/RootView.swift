import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var keyMonitor: Any?

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            // 主区域：侧边栏 + 内容区 + 待播清单面板（覆盖式滑入）
            ZStack(alignment: .trailing) {
                if let lyricsPage = app.lyricsPage {
                    LyricsPlaybackView(page: lyricsPage)
                        .transition(.opacity)
                } else {
                    HStack(spacing: 0) {
                        SidebarView()
                        LibraryContentView()
                    }
                    .transition(.opacity)
                }
                if app.queueOpen, app.lyricsPage == nil {
                    QueuePanelView()
                        .transition(.move(edge: .trailing))
                }
            }
            .clipped()

            PlayBarView()
        }
        .background(app.tokens.winBg)
        .ignoresSafeArea(.container, edges: .top)
        // Toast 悬浮于播放条上方（player.css .toast: bottom 100px）
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(message: toast)
                    .padding(.bottom, 100)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.toast)
        .animation(.easeOut(duration: 0.22), value: app.lyricsPage)
        .onChange(of: app.player.currentId) { _, _ in
            app.refreshLyricsPageForCurrentSong()
        }
        // 拖拽导入（spec: library-import；player.css .drop-overlay）
        .onDrop(of: [.fileURL], isTargeted: $app.dragOver) { providers in
            handleDrop(providers)
        }
        .overlay {
            if app.dragOver { DropOverlay() }
        }
        // 快捷键：空格播放/暂停、⌘+→ 下一首（spec: playback 键盘快捷键）
        .onAppear { installKeyMonitor() }
        .onDisappear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 输入框聚焦时不拦截（field editor 是 NSTextView）
            if event.window?.firstResponder is NSTextView { return event }
            if event.keyCode == 49 { // 空格
                if app.player.currentId != nil {
                    app.player.togglePlay()
                    return nil
                }
            } else if event.keyCode == 124, event.modifierFlags.contains(.command) { // ⌘+→
                app.player.next()
                return nil
            }
            return event
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock(); urls.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            app.importFiles(urls)
        }
        return true
    }
}

// 全窗口拖放遮罩（player.css .drop-overlay / .drop-box）
private struct DropOverlay: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            app.tokens.accentSoft
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(app.tokens.accent)
                Text("拖放以导入音乐")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(app.tokens.text)
                Text("支持 MP3 / M4A / FLAC / WAV / AAC")
                    .font(.system(size: 12.5))
                    .foregroundStyle(app.tokens.text2)
            }
            .padding(.init(top: 36, leading: 56, bottom: 36, trailing: 56))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(app.tokens.winBg)
                    .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(app.tokens.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            )
        }
        .allowsHitTesting(false)
    }
}
