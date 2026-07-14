import XCTest
@testable import Crate

@MainActor
final class AppStateMetadataTests: XCTestCase {
    func testParsesTitleArtistFilenameFallback() {
        let metadata = AppState.metadataWithFilenameFallback(
            filenameStem: "月光 - 徐良&阿悄",
            title: "月光 - 徐良&阿悄",
            hasMetadataTitle: false,
            artist: nil
        )

        XCTAssertEqual(metadata, AppState.FilenameMetadata(title: "月光", artist: "徐良&阿悄"))
    }

    func testKeepsMetadataTitleWhenOnlyArtistFallsBackToFilename() {
        let metadata = AppState.metadataWithFilenameFallback(
            filenameStem: "月光 - 徐良&阿悄",
            title: "月光",
            hasMetadataTitle: true,
            artist: nil
        )

        XCTAssertEqual(metadata, AppState.FilenameMetadata(title: "月光", artist: "徐良&阿悄"))
    }

    func testExistingArtistMetadataWinsOverFilenameFallback() {
        let metadata = AppState.metadataWithFilenameFallback(
            filenameStem: "月光 - 徐良&阿悄",
            title: "月光",
            hasMetadataTitle: true,
            artist: "徐良"
        )

        XCTAssertEqual(metadata, AppState.FilenameMetadata(title: "月光", artist: "徐良"))
    }

    func testDoesNotSplitHyphenWithoutSurroundingSpaces() {
        XCTAssertNil(AppState.metadataFromFilenameStem("月光-徐良&阿悄"))
    }

    func testPersistedSongsBackfillArtistFromFilenameOnLoad() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            AppState.stripsBundledSampleDataOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir
        AppState.stripsBundledSampleDataOverride = false

        let musicDir = tempDir.appendingPathComponent("music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
        let audioURL = musicDir.appendingPathComponent("月光 - 徐良&阿悄.aac")
        try Data().write(to: audioURL)
        try writeLibrary(
            songs: [
                [
                    "id": "song",
                    "title": "月光 - 徐良&阿悄",
                    "artist": NSNull(),
                    "albumId": NSNull(),
                    "duration": 120,
                    "fileURL": audioURL.absoluteString
                ]
            ],
            to: tempDir.appendingPathComponent("library.json")
        )

        let app = AppState()
        app.flushPersistence()

        XCTAssertEqual(app.library.first?.title, "月光")
        XCTAssertEqual(app.library.first?.artist, "徐良&阿悄")
        let persisted = try JSONSerialization.jsonObject(with: Data(contentsOf: tempDir.appendingPathComponent("library.json"))) as? [String: Any]
        let songs = persisted?["songs"] as? [[String: Any]]
        XCTAssertEqual(songs?.first?["title"] as? String, "月光")
        XCTAssertEqual(songs?.first?["artist"] as? String, "徐良&阿悄")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-metadata-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeLibrary(songs: [[String: Any]], to url: URL) throws {
    let payload: [String: Any] = [
        "albums": [],
        "songs": songs,
        "playlists": []
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    try data.write(to: url)
}
