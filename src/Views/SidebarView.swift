import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 原生交通灯悬浮于左上角，预留空间（player.css .traffic）
            Spacer().frame(height: 40)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("资料库")
                    SideItem(
                        icon: "music.note",
                        label: "歌曲",
                        active: app.view == .library
                    ) { app.view = .library }

                    sectionHeader("播放列表")
                    ForEach(app.playlists) { pl in
                        SideItem(
                            icon: "music.note.list",
                            label: pl.name,
                            active: app.view == .playlist(pl.id)
                        ) { app.view = .playlist(pl.id) }
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
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(app.tokens.text3)
            .padding(.init(top: 16, leading: 20, bottom: 6, trailing: 20))
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
