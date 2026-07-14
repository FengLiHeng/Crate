import Foundation
import XCTest
@testable import Crate

@MainActor
final class AppStateLibraryTests: XCTestCase {
    func testSearchUsesLocalizedStandardMatching() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            AppState.stripsBundledSampleDataOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)
        AppState.stripsBundledSampleDataOverride = false

        let app = AppState()
        let song = Song(id: "song", title: "Cafe del Mar", artist: "José", albumId: nil, duration: 120, fileURL: nil)
        app.library = [song]
        app.search = "jose"

        XCTAssertEqual(app.viewSongs.map(\.id), [song.id])
    }

    func testImportShowsDecodeFailureWhenSupportedFileCannotDecode() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            AppState.stripsBundledSampleDataOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)
        AppState.stripsBundledSampleDataOverride = false

        let audioURL = tempDir.appendingPathComponent("broken.mp3")
        try Data("not audio".utf8).write(to: audioURL)
        let app = AppState()

        app.importFiles([audioURL])

        XCTAssertTrue(waitForCondition(timeout: 6) {
            app.toast == "1 个文件无法解码"
        })
        XCTAssertTrue(app.library.isEmpty)
    }

    func testImportPreventsConcurrentTaskAndCanBeCancelled() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            AppState.stripsBundledSampleDataOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)
        AppState.stripsBundledSampleDataOverride = false

        let firstURL = tempDir.appendingPathComponent("first.mp3")
        let secondURL = tempDir.appendingPathComponent("second.mp3")
        try Data("not audio".utf8).write(to: firstURL)
        try Data("not audio".utf8).write(to: secondURL)
        let app = AppState()

        app.importFiles([firstURL])
        XCTAssertTrue(app.importPhase.isImporting)

        app.importFiles([secondURL])
        XCTAssertEqual(app.toast, "音乐正在导入，请稍候或先取消当前任务")

        app.cancelImport()
        XCTAssertEqual(app.importPhase, .idle)
        XCTAssertEqual(app.toast, "已取消音乐导入")
        XCTAssertTrue(app.library.isEmpty)
    }

    func testSemanticDuplicateAlbumsMergeAndKeepArtwork() {
        let existing = Album(
            id: "existing",
            title: "Café del Mar",
            artist: "José",
            year: 2024,
            artworkData: nil,
            h1: 10,
            h2: 40
        )
        let artwork = Data([1, 2, 3])
        let candidate = Album(
            id: "candidate",
            title: " cafe del mar ",
            artist: "JOSE",
            year: 2025,
            artworkData: artwork,
            h1: 80,
            h2: 120
        )
        var albums = [existing]

        let resolvedId = AppState.mergeImportedAlbum(candidate, into: &albums)

        XCTAssertEqual(resolvedId, existing.id)
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].artworkData, artwork)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-library-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
@discardableResult
private func waitForCondition(
    timeout: TimeInterval = 1,
    interval: TimeInterval = 0.01,
    _ condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }
    return condition()
}
