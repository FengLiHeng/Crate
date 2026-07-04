import AppKit
import Foundation

extension AppState {
    var isUpdateBusy: Bool { updatePhase.isBusy }

    @MainActor
    func checkForUpdates() {
        guard !updatePhase.isBusy else { return }
        updatePhase = .checking

        let currentVersion = AppUpdateService.currentBundleVersion()
        Task.detached(priority: .userInitiated) {
            let service = AppUpdateService()
            do {
                let result = try await service.checkForUpdate(currentVersion: currentVersion)
                await MainActor.run { [weak self] in
                    self?.applyUpdateCheckResult(result)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.reportUpdateFailure(error)
                }
            }
        }
    }

    @MainActor
    func installAvailableUpdate() {
        guard let update = availableUpdate, !updatePhase.isBusy else { return }
        updatePhase = .downloading("正在下载 \(update.asset.name)...")

        Task.detached(priority: .userInitiated) {
            let service = AppUpdateService()
            do {
                try await service.downloadAndScheduleInstall(update)
                await MainActor.run { [weak self] in
                    self?.updatePhase = .installing("正在退出并安装更新...")
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.reportUpdateFailure(error)
                }
            }
        }
    }

    @MainActor
    func dismissUpdateDialog() {
        guard !updatePhase.isBusy else { return }
        updateDialogPresented = false
        updatePhase = .idle
    }

    @MainActor
    private func applyUpdateCheckResult(_ result: AppUpdateCheckResult) {
        switch result {
        case .upToDate:
            updatePhase = .idle
            availableUpdate = nil
            updateDialogPresented = false
            showToast("当前已是最新版本")
        case .available(let update):
            updatePhase = .idle
            availableUpdate = update
            updateDialogPresented = true
        }
    }

    @MainActor
    private func reportUpdateFailure(_ error: Error) {
        let message: String
        if let updateError = error as? AppUpdateError {
            message = updateError.userMessage
        } else {
            message = "更新失败：\(error.localizedDescription)"
        }
        updatePhase = .failed(message)
        showToast(message)
    }
}
