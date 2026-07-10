import Foundation
import XCTest
@testable import Crate

final class AppUpdateServiceTests: XCTestCase {
    func testSemanticVersionComparisonIgnoresLeadingVAndTrailingZeroes() throws {
        XCTAssertEqual(try XCTUnwrap(AppVersion("v1.7")), try XCTUnwrap(AppVersion("1.7.0")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("v1.8")), try XCTUnwrap(AppVersion("1.7.9")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("2.0")), try XCTUnwrap(AppVersion("1.99.99")))
        XCTAssertLessThan(try XCTUnwrap(AppVersion("1.7.1")), try XCTUnwrap(AppVersion("1.8")))
    }

    func testVersionParserAcceptsPrereleaseSuffixAfterNumericPrefix() throws {
        XCTAssertEqual(try XCTUnwrap(AppVersion("v1.8.0-beta.1")), try XCTUnwrap(AppVersion("1.8")))
    }

    func testVersionParserRejectsMissingNumericVersion() {
        XCTAssertNil(AppVersion("version-next"))
        XCTAssertNil(AppVersion(""))
    }

    func testDownloadProgressFormatsKnownTotal() {
        let progress = AppUpdateDownloadProgress(downloadedBytes: 512, totalBytes: 1024)

        XCTAssertEqual(progress.fractionCompleted, 0.5)
        XCTAssertEqual(progress.percentText, "50%")
        XCTAssertTrue(progress.message.contains("50%"))
    }

    func testDownloadProgressFormatsUnknownTotal() {
        let progress = AppUpdateDownloadProgress(downloadedBytes: 2048, totalBytes: nil)

        XCTAssertNil(progress.fractionCompleted)
        XCTAssertNil(progress.percentText)
        XCTAssertTrue(progress.message.contains("已下载"))
    }

    func testCompatibleAssetPrefersExactCrateMacOSArm64Zip() throws {
        let exact = GitHubReleaseAsset(
            name: "Crate-v1.8-macOS-arm64.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/exact.zip")),
            size: 10
        )
        let older = GitHubReleaseAsset(
            name: "Crate-v1.7-macOS-arm64.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/older.zip")),
            size: 10
        )
        let unrelated = GitHubReleaseAsset(
            name: "Crate-v1.8-source.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/source.zip")),
            size: 10
        )

        let selected = AppUpdateService.compatibleAsset(
            in: [older, unrelated, exact],
            tagName: "v1.8",
            architecture: "arm64"
        )

        XCTAssertEqual(selected, exact)
    }

    func testCompatibleAssetRequiresZipAppArchitectureAndMacOSName() throws {
        let assets = [
            GitHubReleaseAsset(
                name: "Crate-v1.8-macOS-x86_64.zip",
                browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/x86.zip")),
                size: 10
            ),
            GitHubReleaseAsset(
                name: "Crate-v1.8-macOS-arm64.dmg",
                browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/app.dmg")),
                size: 10
            ),
            GitHubReleaseAsset(
                name: "Other-v1.8-macOS-arm64.zip",
                browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/other.zip")),
                size: 10
            )
        ]

        let selected = AppUpdateService.compatibleAsset(
            in: assets,
            tagName: "v1.8",
            architecture: "arm64"
        )

        XCTAssertNil(selected)
    }

    func testCompatibleAssetRejectsSimilarBackupName() throws {
        let backup = GitHubReleaseAsset(
            name: "Backup-Crate-v1.8-macOS-arm64.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Backup-Crate-v1.8-macOS-arm64.zip")),
            size: 10,
            digest: "sha256:\(String(repeating: "0", count: 64))"
        )

        XCTAssertNil(AppUpdateService.compatibleAsset(
            in: [backup],
            tagName: "v1.8",
            architecture: "arm64"
        ))
    }

    func testReleaseAssetDecodesGitHubSHA256Digest() throws {
        let json = """
        {
          "name": "Crate-v1.8-macOS-arm64.zip",
          "browser_download_url": "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip",
          "size": 5,
          "digest": "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        }
        """

        let asset = try JSONDecoder().decode(GitHubReleaseAsset.self, from: Data(json.utf8))

        XCTAssertEqual(asset.digest, "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testAssetMetadataRequiresExactTrustedGitHubReleaseURL() throws {
        let asset = GitHubReleaseAsset(
            name: "Crate-v1.8-macOS-arm64.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://example.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip")),
            size: 5,
            digest: "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )

        XCTAssertThrowsError(try AppUpdateService.validateAssetMetadata(asset, tagName: "v1.8")) { error in
            XCTAssertEqual(error as? AppUpdateError, .invalidAssetDownloadURL)
        }
    }

    func testAssetMetadataRequiresSizeAndSHA256Digest() throws {
        let asset = GitHubReleaseAsset(
            name: "Crate-v1.8-macOS-arm64.zip",
            browserDownloadURL: try XCTUnwrap(URL(string: "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip")),
            size: nil,
            digest: nil
        )

        XCTAssertThrowsError(try AppUpdateService.validateAssetMetadata(asset, tagName: "v1.8")) { error in
            XCTAssertEqual(error as? AppUpdateError, .missingAssetIntegrityMetadata(asset.name))
        }
    }

    func testDownloadedAssetAcceptsMatchingSizeAndSHA256() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let archiveURL = tempDir.appendingPathComponent("Crate-v1.8-macOS-arm64.zip")
        try Data("hello".utf8).write(to: archiveURL)
        let asset = GitHubReleaseAsset(
            name: archiveURL.lastPathComponent,
            browserDownloadURL: try XCTUnwrap(URL(string: "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip")),
            size: 5,
            digest: "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )

        XCTAssertNoThrow(try AppUpdateService.validateDownloadedAsset(at: archiveURL, asset: asset))
    }

    func testDownloadedAssetRejectsSizeMismatch() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let archiveURL = tempDir.appendingPathComponent("Crate-v1.8-macOS-arm64.zip")
        try Data("hello".utf8).write(to: archiveURL)
        let asset = GitHubReleaseAsset(
            name: archiveURL.lastPathComponent,
            browserDownloadURL: try XCTUnwrap(URL(string: "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip")),
            size: 6,
            digest: "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )

        XCTAssertThrowsError(try AppUpdateService.validateDownloadedAsset(at: archiveURL, asset: asset)) { error in
            XCTAssertEqual(error as? AppUpdateError, .downloadedSizeMismatch(expected: 6, actual: 5))
        }
    }

    func testDownloadedAssetRejectsDigestMismatch() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let archiveURL = tempDir.appendingPathComponent("Crate-v1.8-macOS-arm64.zip")
        try Data("hello".utf8).write(to: archiveURL)
        let asset = GitHubReleaseAsset(
            name: archiveURL.lastPathComponent,
            browserDownloadURL: try XCTUnwrap(URL(string: "https://github.com/FengLiHeng/Crate/releases/download/v1.8/Crate-v1.8-macOS-arm64.zip")),
            size: 5,
            digest: "sha256:\(String(repeating: "0", count: 64))"
        )

        XCTAssertThrowsError(try AppUpdateService.validateDownloadedAsset(at: archiveURL, asset: asset)) { error in
            XCTAssertEqual(error as? AppUpdateError, .downloadedDigestMismatch)
        }
    }

    func testInstallationScriptRestoresPreviousAppWhenCopyLeavesPartialTarget() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let currentApp = tempDir.appendingPathComponent("Crate.app", isDirectory: true)
        let newApp = tempDir.appendingPathComponent("NewCrate.app", isDirectory: true)
        let workDir = tempDir.appendingPathComponent("Work", isDirectory: true)
        try FileManager.default.createDirectory(at: currentApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: currentApp.appendingPathComponent("version.txt"))
        try Data("new".utf8).write(to: newApp.appendingPathComponent("version.txt"))

        let failingDitto = try makeFailingDittoShim(in: tempDir)
        let scriptURL = tempDir.appendingPathComponent("install-crate-update.sh")
        let script = AppUpdateService.installationScript.replacing(
            "/usr/bin/ditto \"$NEW_APP\" \"$CURRENT_APP\"",
            with: "\"\(failingDitto.path)\" \"$NEW_APP\" \"$CURRENT_APP\""
        )
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path, currentApp.path, newApp.path, workDir.path]
        try process.run()
        process.waitUntilExit()

        XCTAssertNotEqual(process.terminationStatus, 0)
        XCTAssertEqual(try String(contentsOf: currentApp.appendingPathComponent("version.txt")), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentApp.appendingPathComponent("partial.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentApp.path + ".previous"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: workDir.path))
    }

    func testInstallerLauncherStartsNoHupInBackgroundWithLogRedirection() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let launcher = AppUpdateService.installerLauncher(
            scriptURL: tempDir.appendingPathComponent("install.sh"),
            currentAppURL: tempDir.appendingPathComponent("Crate.app"),
            newAppURL: tempDir.appendingPathComponent("NewCrate.app"),
            workDir: tempDir.appendingPathComponent("Work"),
            logURL: tempDir.appendingPathComponent("install.log")
        )

        XCTAssertEqual(launcher.executableURL.path, "/bin/sh")
        XCTAssertEqual(launcher.arguments.first, "-c")
        XCTAssertTrue(launcher.arguments[1].contains("/usr/bin/nohup"))
        XCTAssertTrue(launcher.arguments[1].contains("&"))
        XCTAssertTrue(launcher.arguments.contains(tempDir.appendingPathComponent("install.log").path))
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-update-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeFailingDittoShim(in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent("failing-ditto.sh")
    let script = """
    #!/bin/sh
    set -eu
    TARGET="$2"
    /bin/mkdir -p "$TARGET"
    /bin/echo partial > "$TARGET/partial.txt"
    exit 17
    """
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}
