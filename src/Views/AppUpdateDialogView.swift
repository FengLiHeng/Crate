import AppKit
import SwiftUI

struct AppUpdateDialogView: View {
    @Environment(AppState.self) private var app

    var update: AvailableAppUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(app.tokens.accent)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现新版本")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(app.tokens.text)
                    Text("Crate \(update.displayVersion)")
                        .font(.system(size: 13))
                        .foregroundStyle(app.tokens.text2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("发布说明")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(app.tokens.text2)
                ScrollView {
                    Text(update.releaseNotesPreview)
                        .font(.system(size: 12.5))
                        .foregroundStyle(app.tokens.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(12)
                .background(app.tokens.panelBg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(app.tokens.sep, lineWidth: 1)
                )
            }

            if let message = app.updatePhase.message {
                VStack(alignment: .leading, spacing: 8) {
                    if let fraction = app.updatePhase.downloadFractionCompleted {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                    } else if app.updatePhase.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(statusColor)
                }
                .frame(minHeight: 18, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button("在 GitHub 查看") {
                    NSWorkspace.shared.open(update.releasePageURL)
                }
                .disabled(app.updatePhase.isBusy)

                Spacer()

                Button("稍后") {
                    app.dismissUpdateDialog()
                }
                .disabled(app.updatePhase.isBusy)

                Button(primaryButtonTitle) {
                    app.installAvailableUpdate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(app.updatePhase.isBusy)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(app.tokens.winBg)
    }

    private var primaryButtonTitle: String {
        switch app.updatePhase {
        case .checking:
            return "正在检查"
        case .downloading:
            return "正在下载"
        case .preparingInstall:
            return "正在准备"
        case .installing:
            return "正在安装"
        case .idle, .failed:
            return "下载并安装"
        }
    }

    private var statusColor: Color {
        if case .failed = app.updatePhase {
            return .red
        }
        return app.tokens.text2
    }
}
