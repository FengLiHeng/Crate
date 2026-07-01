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
