import CryptoKit
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
    var digest: String? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case digest
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

struct AppUpdateDownloadProgress: Equatable, Sendable {
    var downloadedBytes: Int64
    var totalBytes: Int64?

    var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(downloadedBytes) / Double(totalBytes), 0), 1)
    }

    var percentText: String? {
        guard let fractionCompleted else { return nil }
        return "\(Int((fractionCompleted * 100).rounded()))%"
    }

    var message: String {
        if let totalBytes {
            return "正在下载更新包 \(percentText ?? "")（\(Self.formattedBytes(downloadedBytes)) / \(Self.formattedBytes(totalBytes))）"
        }
        return "正在下载更新包（已下载 \(Self.formattedBytes(downloadedBytes))）"
    }

    static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum AppUpdatePhase: Equatable {
    case idle
    case checking
    case downloading(AppUpdateDownloadProgress)
    case preparingInstall(String)
    case installing(String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .preparingInstall, .installing:
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
        case .downloading(let progress):
            return progress.message
        case .preparingInstall(let message), .installing(let message), .failed(let message):
            return message
        }
    }

    var downloadFractionCompleted: Double? {
        if case .downloading(let progress) = self {
            return progress.fractionCompleted
        }
        return nil
    }
}

enum AppUpdateError: Error, Equatable {
    case invalidLatestReleaseURL
    case invalidServerResponse
    case httpStatus(Int)
    case invalidReleaseVersion(String)
    case missingCompatibleAsset(String)
    case invalidAssetDownloadURL
    case missingAssetIntegrityMetadata(String)
    case downloadedSizeMismatch(expected: Int64, actual: Int64)
    case downloadedDigestMismatch
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
        case .invalidAssetDownloadURL:
            return "更新包地址不是受信任的 Crate GitHub Release 地址"
        case .missingAssetIntegrityMetadata(let name):
            return "更新包 \(name) 缺少有效的大小或 SHA-256 校验信息"
        case .downloadedSizeMismatch:
            return "更新包大小与 GitHub Release 记录不一致"
        case .downloadedDigestMismatch:
            return "更新包 SHA-256 校验失败"
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
        try Self.validateAssetMetadata(asset, tagName: release.tagName)

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

    typealias DownloadProgressHandler = @Sendable (AppUpdateDownloadProgress) async -> Void
    typealias UpdateStageHandler = @Sendable (String) async -> Void

    func downloadAndScheduleInstall(
        _ update: AvailableAppUpdate,
        progress: @escaping DownloadProgressHandler = { _ in },
        stage: @escaping UpdateStageHandler = { _ in }
    ) async throws {
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

        try await download(update.asset, to: archiveURL, progress: progress)
        try Self.validateDownloadedAsset(at: archiveURL, asset: update.asset)

        await stage("正在解压更新包...")
        try extractZip(at: archiveURL, to: extractDir)
        await stage("正在校验更新包...")
        let extractedAppURL = try findExtractedApp(in: extractDir)
        try validateExtractedApp(extractedAppURL, expectedVersion: update.version)
        let currentAppURL = try currentAppBundleURL()
        try validateWritableInstallLocation(for: currentAppURL)
        await stage("正在启动安装器...")
        try scheduleReplacement(currentAppURL: currentAppURL, newAppURL: extractedAppURL, workDir: workDir)
        shouldCleanWorkDir = false
    }

    private func download(
        _ asset: GitHubReleaseAsset,
        to archiveURL: URL,
        progress: @escaping DownloadProgressHandler
    ) async throws {
        let fileManager = FileManager.default
        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("Crate Update Checker", forHTTPHeaderField: "User-Agent")

        let byteStream: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (byteStream, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw AppUpdateError.downloadFailed
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.httpStatus(httpResponse.statusCode)
        }
        guard response.url?.scheme?.lowercased() == "https" else {
            throw AppUpdateError.invalidAssetDownloadURL
        }

        let responseLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        let assetLength = asset.size.flatMap { $0 > 0 ? Int64($0) : nil }
        let totalBytes = responseLength ?? assetLength

        do {
            if fileManager.fileExists(atPath: archiveURL.path) {
                try fileManager.removeItem(at: archiveURL)
            }
            guard fileManager.createFile(atPath: archiveURL.path, contents: nil),
                  let fileHandle = FileHandle(forWritingAtPath: archiveURL.path) else {
                throw AppUpdateError.downloadFailed
            }
            defer { try? fileHandle.close() }

            var downloadedBytes: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(64 * 1024)
            var lastReportedMessage: String?

            func report(force: Bool = false) async {
                let current = AppUpdateDownloadProgress(downloadedBytes: downloadedBytes, totalBytes: totalBytes)
                guard force || current.message != lastReportedMessage else { return }
                lastReportedMessage = current.message
                await progress(current)
            }

            await report(force: true)
            for try await byte in byteStream {
                buffer.append(byte)
                guard buffer.count >= 64 * 1024 else { continue }
                try fileHandle.write(contentsOf: buffer)
                downloadedBytes += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                await report()
            }
            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
                downloadedBytes += Int64(buffer.count)
            }
            await report(force: true)
        } catch let updateError as AppUpdateError {
            throw updateError
        } catch {
            throw AppUpdateError.downloadFailed
        }
    }

    static func compatibleAsset(
        in assets: [GitHubReleaseAsset],
        tagName: String,
        architecture: String
    ) -> GitHubReleaseAsset? {
        let expectedName = "Crate-\(tagName)-macOS-\(architecture).zip"
        return assets.first { $0.name == expectedName }
    }

    static func validateAssetMetadata(_ asset: GitHubReleaseAsset, tagName: String) throws {
        let expectedPath = "/\(owner)/\(repo)/releases/download/\(tagName)/\(asset.name)"
        guard asset.browserDownloadURL.scheme?.lowercased() == "https",
              asset.browserDownloadURL.host?.lowercased() == "github.com",
              asset.browserDownloadURL.path == expectedPath,
              asset.browserDownloadURL.query == nil,
              asset.browserDownloadURL.fragment == nil else {
            throw AppUpdateError.invalidAssetDownloadURL
        }
        guard let size = asset.size, size > 0,
              sha256Digest(from: asset.digest) != nil else {
            throw AppUpdateError.missingAssetIntegrityMetadata(asset.name)
        }
    }

    static func validateDownloadedAsset(at url: URL, asset: GitHubReleaseAsset) throws {
        guard let expectedSize = asset.size, expectedSize > 0,
              let expectedDigest = sha256Digest(from: asset.digest) else {
            throw AppUpdateError.missingAssetIntegrityMetadata(asset.name)
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw AppUpdateError.downloadFailed
        }
        let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        guard actualSize == Int64(expectedSize) else {
            throw AppUpdateError.downloadedSizeMismatch(
                expected: Int64(expectedSize),
                actual: actualSize
            )
        }

        let actualDigest: String
        do {
            actualDigest = try sha256Hex(ofFileAt: url)
        } catch {
            throw AppUpdateError.downloadFailed
        }
        guard actualDigest == expectedDigest else {
            throw AppUpdateError.downloadedDigestMismatch
        }
    }

    static func sha256Digest(from value: String?) -> String? {
        guard let value else { return nil }
        let prefix = "sha256:"
        guard value.lowercased().hasPrefix(prefix) else { return nil }
        let digest = String(value.dropFirst(prefix.count)).lowercased()
        guard digest.count == 64, digest.allSatisfy(\.isHexDigit) else { return nil }
        return digest
    }

    private static func sha256Hex(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { byte in
            let value = String(byte, radix: 16)
            return value.count == 1 ? "0\(value)" : value
        }.joined()
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
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrateUpdate-\(UUID().uuidString).log")
        let script = Self.installationScript

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            throw AppUpdateError.installScriptFailed(error.localizedDescription)
        }

        let launcher = Self.installerLauncher(
            scriptURL: scriptURL,
            currentAppURL: currentAppURL,
            newAppURL: newAppURL,
            workDir: workDir,
            logURL: logURL
        )
        let process = Process()
        process.executableURL = launcher.executableURL
        process.arguments = launcher.arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
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

    static func installerLauncher(
        scriptURL: URL,
        currentAppURL: URL,
        newAppURL: URL,
        workDir: URL,
        logURL: URL
    ) -> (executableURL: URL, arguments: [String]) {
        let launcher = """
        /usr/bin/nohup /bin/sh "$1" "$2" "$3" "$4" > "$5" 2>&1 < /dev/null &
        """
        return (
            URL(fileURLWithPath: "/bin/sh"),
            [
                "-c",
                launcher,
                "crate-update-installer-launcher",
                scriptURL.path,
                currentAppURL.path,
                newAppURL.path,
                workDir.path,
                logURL.path
            ]
        )
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
