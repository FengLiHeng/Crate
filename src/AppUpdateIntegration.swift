import AppKit
import Darwin
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
        let initialProgress = AppUpdateDownloadProgress(
            downloadedBytes: 0,
            totalBytes: update.asset.size.map(Int64.init)
        )
        updatePhase = .downloading(initialProgress)

        Task.detached(priority: .userInitiated) {
            let service = AppUpdateService()
            do {
                try await service.downloadAndScheduleInstall(
                    update,
                    progress: { progress in
                        await MainActor.run { [weak self] in
                            self?.updatePhase = .downloading(progress)
                        }
                    },
                    stage: { message in
                        await MainActor.run { [weak self] in
                            self?.updatePhase = .preparingInstall(message)
                        }
                    }
                )
                await MainActor.run { [weak self] in
                    self?.beginUpdateTermination()
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

    @MainActor
    private func beginUpdateTermination() {
        updatePhase = .installing("安装器已启动，正在退出 Crate...")
        flushPersistence()
        NSApp.terminate(nil)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self,
                  case .installing = self.updatePhase else { return }
            self.updatePhase = .installing("安装器已启动，正在强制退出 Crate...")
            self.flushPersistence()
            Darwin.exit(0)
        }
    }
}
