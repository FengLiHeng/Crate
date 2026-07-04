import Foundation

struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    let rawValue: String
    let components: [Int]

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var version = trimmed
        if version.lowercased().hasPrefix("v") {
            version.removeFirst()
        }

        var parsed: [Int] = []
        var current = ""
        for ch in version {
            if ch.isNumber {
                current.append(ch)
            } else if ch == "." {
                guard !current.isEmpty, let value = Int(current) else { break }
                parsed.append(value)
                current = ""
            } else {
                break
            }
        }
        if !current.isEmpty, let value = Int(current) {
            parsed.append(value)
        }

        guard !parsed.isEmpty else { return nil }
        self.rawValue = trimmed
        self.components = parsed
    }

    var description: String { rawValue }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !((lhs < rhs) || (rhs < lhs))
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

struct GitHubReleaseAsset: Decodable, Equatable, Sendable {
    var name: String
    var browserDownloadURL: URL
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

struct GitHubRelease: Decodable, Equatable, Sendable {
    var tagName: String
    var name: String?
    var htmlURL: URL
    var body: String?
    var assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case assets
    }
}

struct AvailableAppUpdate: Equatable, Sendable {
    var release: GitHubRelease
    var version: AppVersion
    var asset: GitHubReleaseAsset

    var displayVersion: String { release.tagName }
    var releasePageURL: URL { release.htmlURL }

    var releaseNotesPreview: String {
        let body = (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return "此版本没有填写发布说明。" }
        let lines = body
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let preview = lines.prefix(8).joined(separator: "\n")
        return preview.isEmpty ? "此版本没有填写发布说明。" : preview
    }
}

enum AppUpdateCheckResult: Equatable, Sendable {
    case upToDate(current: AppVersion, latest: AppVersion)
    case available(AvailableAppUpdate)
}

enum AppUpdatePhase: Equatable {
    case idle
    case checking
    case downloading(String)
    case installing(String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            return true
        case .idle, .failed:
            return false
        }
    }

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .checking:
            return "正在检查更新..."
        case .downloading(let message), .installing(let message), .failed(let message):
            return message
        }
    }
}

enum AppUpdateError: Error, Equatable {
    case invalidLatestReleaseURL
    case invalidServerResponse
    case httpStatus(Int)
    case invalidReleaseVersion(String)
    case missingCompatibleAsset(String)
    case downloadFailed
    case extractionFailed(String)
    case notRunningFromAppBundle
    case appLocationNotWritable(String)
    case missingExtractedApp
    case invalidBundleIdentifier(String?)
    case invalidBundleVersion(String?)
    case installScriptFailed(String)

    var userMessage: String {
        switch self {
        case .invalidLatestReleaseURL:
            return "更新地址无效"
        case .invalidServerResponse:
            return "GitHub 返回了无法识别的更新信息"
        case .httpStatus(let status):
            return "检查更新失败，GitHub 返回状态码 \(status)"
        case .invalidReleaseVersion(let version):
            return "最新版本号无法识别：\(version)"
        case .missingCompatibleAsset(let version):
            return "版本 \(version) 缺少可安装的 macOS arm64 更新包"
        case .downloadFailed:
            return "更新包下载失败"
        case .extractionFailed(let detail):
            return "更新包解压失败：\(detail)"
        case .notRunningFromAppBundle:
            return "请从 Crate.app 启动后再安装更新"
        case .appLocationNotWritable(let path):
            return "无法写入当前位置：\(path)"
        case .missingExtractedApp:
            return "更新包内没有找到 Crate.app"
        case .invalidBundleIdentifier:
            return "更新包不是有效的 Crate 应用"
        case .invalidBundleVersion(let version):
            if let version {
                return "更新包版本不匹配：\(version)"
            }
            return "更新包缺少版本信息"
        case .installScriptFailed(let detail):
            return "安装更新失败：\(detail)"
        }
    }
}

struct AppUpdateService: Sendable {
    static let owner = "FengLiHeng"
    static let repo = "Crate"
    static let bundleIdentifier = "com.crate.player"

    static var latestReleaseURL: URL? {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")
    }

    static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static func currentBundleVersion(in bundle: Bundle = .main) -> String {
        if let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
           !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return version
        }
        return "0.0.0"
    }

    func checkForUpdate(currentVersion currentVersionString: String = Self.currentBundleVersion()) async throws -> AppUpdateCheckResult {
        guard let currentVersion = AppVersion(currentVersionString) else {
            throw AppUpdateError.invalidReleaseVersion(currentVersionString)
        }

        let release = try await fetchLatestRelease()
        guard let latestVersion = AppVersion(release.tagName) else {
            throw AppUpdateError.invalidReleaseVersion(release.tagName)
        }

        guard latestVersion > currentVersion else {
            return .upToDate(current: currentVersion, latest: latestVersion)
        }

        guard let asset = Self.compatibleAsset(in: release.assets, tagName: release.tagName, architecture: Self.currentArchitecture) else {
            throw AppUpdateError.missingCompatibleAsset(release.tagName)
        }

        return .available(AvailableAppUpdate(release: release, version: latestVersion, asset: asset))
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = Self.latestReleaseURL else {
            throw AppUpdateError.invalidLatestReleaseURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Crate Update Checker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateError.invalidServerResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw AppUpdateError.invalidServerResponse
        }
    }

    func downloadAndScheduleInstall(_ update: AvailableAppUpdate) async throws {
        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory
            .appendingPathComponent("CrateUpdate-\(UUID().uuidString)", isDirectory: true)
        var shouldCleanWorkDir = true
        defer {
            if shouldCleanWorkDir {
                try? fileManager.removeItem(at: workDir)
            }
        }

        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        let archiveURL = workDir.appendingPathComponent(update.asset.name)
        let extractDir = workDir.appendingPathComponent("Extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        var request = URLRequest(url: update.asset.browserDownloadURL)
        request.setValue("Crate Update Checker", forHTTPHeaderField: "User-Agent")
        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.httpStatus(httpResponse.statusCode)
        }

        do {
            if fileManager.fileExists(atPath: archiveURL.path) {
                try fileManager.removeItem(at: archiveURL)
            }
            try fileManager.moveItem(at: downloadedURL, to: archiveURL)
        } catch {
            throw AppUpdateError.downloadFailed
        }

        try extractZip(at: archiveURL, to: extractDir)
        let extractedAppURL = try findExtractedApp(in: extractDir)
        try validateExtractedApp(extractedAppURL, expectedVersion: update.version)
        let currentAppURL = try currentAppBundleURL()
        try validateWritableInstallLocation(for: currentAppURL)
        try scheduleReplacement(currentAppURL: currentAppURL, newAppURL: extractedAppURL, workDir: workDir)
        shouldCleanWorkDir = false
    }

    static func compatibleAsset(
        in assets: [GitHubReleaseAsset],
        tagName: String,
        architecture: String
    ) -> GitHubReleaseAsset? {
        let lowerTag = tagName.lowercased()
        let lowerArch = architecture.lowercased()
        let scored = assets.compactMap { asset -> (score: Int, asset: GitHubReleaseAsset)? in
            let lowerName = asset.name.lowercased()
            guard lowerName.hasSuffix(".zip"),
                  lowerName.contains("crate"),
                  lowerName.contains("macos"),
                  lowerName.contains(lowerArch) else { return nil }

            var score = 0
            if lowerName.contains("crate-\(lowerTag)-macos-\(lowerArch).zip") { score += 8 }
            if lowerName.contains(lowerTag) { score += 4 }
            if lowerName.contains("arm64") { score += 2 }
            if lowerName.contains("macos") { score += 1 }
            return (score, asset)
        }
        return scored.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.asset.name.localizedStandardCompare(rhs.asset.name) == .orderedAscending
            }
            return lhs.score < rhs.score
        }.last?.asset
    }

    private func extractZip(at archiveURL: URL, to directoryURL: URL) throws {
        do {
            try runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, directoryURL.path]
            )
        } catch AppUpdateError.installScriptFailed(let detail) {
            throw AppUpdateError.extractionFailed(detail)
        }
    }

    private func findExtractedApp(in directoryURL: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppUpdateError.missingExtractedApp
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app",
                  url.lastPathComponent.caseInsensitiveCompare("Crate.app") == .orderedSame else { continue }
            return url
        }
        throw AppUpdateError.missingExtractedApp
    }

    private func validateExtractedApp(_ appURL: URL, expectedVersion: AppVersion) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw AppUpdateError.invalidBundleIdentifier(nil)
        }
        guard bundle.bundleIdentifier == Self.bundleIdentifier else {
            throw AppUpdateError.invalidBundleIdentifier(bundle.bundleIdentifier)
        }
        guard let versionString = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
              let version = AppVersion(versionString) else {
            throw AppUpdateError.invalidBundleVersion(nil)
        }
        guard version == expectedVersion else {
            throw AppUpdateError.invalidBundleVersion(versionString)
        }
    }

    private func currentAppBundleURL() throws -> URL {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else {
            throw AppUpdateError.notRunningFromAppBundle
        }
        return bundleURL
    }

    private func validateWritableInstallLocation(for appURL: URL) throws {
        let parent = appURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw AppUpdateError.appLocationNotWritable(parent.path)
        }
    }

    private func scheduleReplacement(currentAppURL: URL, newAppURL: URL, workDir: URL) throws {
        let scriptURL = workDir.appendingPathComponent("install-crate-update.sh")
        let script = Self.installationScript

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            throw AppUpdateError.installScriptFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path, currentAppURL.path, newAppURL.path, workDir.path]
        do {
            try process.run()
        } catch {
            throw AppUpdateError.installScriptFailed(error.localizedDescription)
        }
    }

    static var installationScript: String {
        """
        #!/bin/sh
        set -eu
        CURRENT_APP="$1"
        NEW_APP="$2"
        WORK_DIR="$3"
        BACKUP_APP="${CURRENT_APP}.previous"

        restore_backup() {
            if [ -d "$BACKUP_APP" ]; then
                /bin/rm -rf "$CURRENT_APP"
                /bin/mv "$BACKUP_APP" "$CURRENT_APP"
            fi
            /bin/rm -rf "$WORK_DIR"
        }
        trap restore_backup EXIT

        while /usr/bin/pgrep -x "Crate" >/dev/null 2>&1; do
            /bin/sleep 0.2
        done

        /bin/rm -rf "$BACKUP_APP"
        if [ -d "$CURRENT_APP" ]; then
            /bin/mv "$CURRENT_APP" "$BACKUP_APP"
        fi
        /usr/bin/ditto "$NEW_APP" "$CURRENT_APP"
        /bin/rm -rf "$BACKUP_APP"
        trap - EXIT
        /usr/bin/open "$CURRENT_APP"
        /bin/rm -rf "$WORK_DIR"
        """
    }

    private func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AppUpdateError.installScriptFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppUpdateError.installScriptFailed(output?.isEmpty == false ? output! : "退出码 \(process.terminationStatus)")
        }
    }
}
