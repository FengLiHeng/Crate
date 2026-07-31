import Foundation
import XCTest
@testable import Crate

@MainActor
final class AppStateLibraryTests: XCTestCase {
    func testSongDragPayloadUsesStableExportedContentType() {
        XCTAssertEqual(SongDragPayload.contentType.identifier, "com.crate.song-ids")
        XCTAssertEqual(SongDragPayload.typeIdentifier, SongDragPayload.contentType.identifier)
    }

    func testPlaylistDragPayloadIsStableAndSeparateFromSongDrop() {
        XCTAssertEqual(PlaylistDragPayload.contentType, .text)
        XCTAssertEqual(PlaylistDragPayload.typeIdentifier, PlaylistDragPayload.contentType.identifier)
        XCTAssertNotEqual(PlaylistDragPayload.contentType, SongDragPayload.contentType)
    }

    func testMoveGroupReordersOrdinaryGroupsAndKeepsFavoritesFirst() throws {
        let fixture = try LibraryStateFixture()
        defer { fixture.cleanup() }
        let app = fixture.makeApp()
        let first = try XCTUnwrap(app.createGroup(named: "第一组"))
        let second = try XCTUnwrap(app.createGroup(named: "第二组"))
        let third = try XCTUnwrap(app.createGroup(named: "第三组"))

        app.moveGroup(third.id, to: 1)
        XCTAssertEqual(
            app.playlists.map(\.id),
            [AppState.favoritesGroupId, third.id, first.id, second.id]
        )

        app.moveGroup(third.id, to: Int.max)
        XCTAssertEqual(
            app.playlists.map(\.id),
            [AppState.favoritesGroupId, first.id, second.id, third.id]
        )

        app.moveGroup(AppState.favoritesGroupId, to: 3)
        XCTAssertEqual(
            app.playlists.map(\.id),
            [AppState.favoritesGroupId, first.id, second.id, third.id]
        )
    }

    func testLegacySongWithoutDateAddedDecodesAndRemainsUsable() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            AppState.stripsBundledSampleDataOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        let storeDir = tempDir.appendingPathComponent("store", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        AppState.storeDirectoryOverride = storeDir
        AppState.stripsBundledSampleDataOverride = false
        let json = """
        {
          "albums": [],
          "songs": [
            {
              "id": "legacy",
              "title": "Legacy",
              "artist": null,
              "albumId": null,
              "duration": 120,
              "fileURL": null
            }
          ],
          "playlists": []
        }
        """
        try Data(json.utf8).write(to: storeDir.appendingPathComponent("library.json"))

        let app = AppState()

        XCTAssertEqual(app.library.map(\.id), ["legacy"])
        XCTAssertNil(app.library.first?.dateAdded)
    }

    func testVisibleSongsSortByMetadataAndKeepMissingDatesLast() throws {
        let fixture = try LibraryStateFixture()
        defer { fixture.cleanup() }
        let old = Song(
            id: "old",
            title: "Zulu",
            artist: "Beta",
            albumId: "album-b",
            duration: 10,
            fileURL: nil,
            dateAdded: Date(timeIntervalSince1970: 10)
        )
        let new = Song(
            id: "new",
            title: "Alpha",
            artist: "Zulu",
            albumId: "album-a",
            duration: 10,
            fileURL: nil,
            dateAdded: Date(timeIntervalSince1970: 20)
        )
        let legacy = Song(
            id: "legacy",
            title: "Middle",
            artist: "Alpha",
            albumId: nil,
            duration: 10,
            fileURL: nil
        )
        let app = fixture.makeApp()
        app.albums = [
            Album(id: "album-a", title: "First", artist: "Zulu", year: 0, h1: 0, h2: 0),
            Album(id: "album-b", title: "Second", artist: "Beta", year: 0, h1: 0, h2: 0),
        ]
        app.library = [old, new, legacy]

        app.librarySortField = .title
        app.librarySortDirection = .ascending
        XCTAssertEqual(app.viewSongs.map(\.id), ["new", "legacy", "old"])

        app.librarySortField = .artist
        XCTAssertEqual(app.viewSongs.map(\.id), ["legacy", "old", "new"])

        app.librarySortField = .album
        XCTAssertEqual(app.viewSongs.map(\.id), ["legacy", "new", "old"])

        app.librarySortField = .dateAdded
        XCTAssertEqual(app.viewSongs.map(\.id), ["old", "new", "legacy"])
        app.librarySortDirection = .descending
        XCTAssertEqual(app.viewSongs.map(\.id), ["new", "old", "legacy"])
    }

    func testSearchRemovesHiddenSongsFromSelection() throws {
        let fixture = try LibraryStateFixture()
        defer { fixture.cleanup() }
        let first = Song(id: "first", title: "Alpha", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Beta", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let app = fixture.makeApp()
        app.library = [first, second]
        app.setSongSelection([first.id, second.id])

        app.search = "Alpha"

        XCTAssertEqual(app.selectedSongIds, [first.id])
        XCTAssertEqual(app.selectedId, first.id)
    }

    func testBatchFavoriteGroupQueueAndRemovalOperations() throws {
        let fixture = try LibraryStateFixture()
        defer { fixture.cleanup() }
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let app = fixture.makeApp()
        app.library = [first, second]
        let group = try XCTUnwrap(app.createGroup(named: "批量测试"))

        app.setFavorite(true, songIds: [first.id, second.id, first.id])
        XCTAssertEqual(app.favoritesGroup?.songIds, [first.id, second.id])
        app.setFavorite(false, songIds: [second.id])
        XCTAssertEqual(app.favoritesGroup?.songIds, [first.id])

        XCTAssertEqual(app.addSongs([second.id, first.id, second.id], toGroupId: group.id), 2)
        XCTAssertEqual(
            app.playlists.first(where: { $0.id == group.id })?.songIds,
            [second.id, first.id]
        )
        XCTAssertEqual(app.addSongs([first.id], toGroupId: group.id), 0)

        app.addSongsToQueue([second.id, first.id, second.id])
        XCTAssertEqual(app.player.manualQueue, [second.id, first.id])

        app.removeSongs([first.id], fromGroupId: group.id)
        XCTAssertEqual(app.playlists.first(where: { $0.id == group.id })?.songIds, [second.id])
        XCTAssertEqual(app.library.count, 2)

        app.view = .library
        app.requestRemoval(of: [first.id, second.id])
        XCTAssertEqual(app.pendingSongRemoval?.songIds, [first.id, second.id])
        app.confirmPendingSongRemoval()
        XCTAssertTrue(app.library.isEmpty)
        XCTAssertTrue(app.playlists.allSatisfy(\.songIds.isEmpty))
        XCTAssertTrue(app.player.manualQueue.isEmpty)
    }

    func testFileImportRecordsDateAdded() throws {
        let fixture = try LibraryStateFixture()
        defer { fixture.cleanup() }
        let audioURL = fixture.rootURL.appendingPathComponent("Imported.wav")
        try makeLibraryPCM16WAV(frameCount: 8_000).write(to: audioURL)
        let app = fixture.makeApp()

        app.importFiles([audioURL])

        XCTAssertTrue(waitForCondition(timeout: 8) {
            app.importPhase == .idle && app.library.count == 1
        })
        XCTAssertNotNil(app.library.first?.dateAdded)
    }

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

@MainActor
private final class LibraryStateFixture {
    let rootURL: URL
    let storeURL: URL

    init() throws {
        rootURL = try makeTemporaryDirectory()
        storeURL = rootURL.appendingPathComponent("store", isDirectory: true)
        AppState.storeDirectoryOverride = storeURL
        AppState.stripsBundledSampleDataOverride = false
    }

    func makeApp() -> AppState {
        AppState()
    }

    func cleanup() {
        AppState.storeDirectoryOverride = nil
        AppState.stripsBundledSampleDataOverride = nil
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-library-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeLibraryPCM16WAV(frameCount: Int) -> Data {
    let sampleRate: UInt32 = 8_000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * UInt32(blockAlign)
    let dataSize = UInt32(frameCount) * UInt32(blockAlign)
    var data = Data()
    data.append(contentsOf: Array("RIFF".utf8))
    appendLibraryLittleEndian(UInt32(36) + dataSize, to: &data)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    appendLibraryLittleEndian(UInt32(16), to: &data)
    appendLibraryLittleEndian(UInt16(1), to: &data)
    appendLibraryLittleEndian(channels, to: &data)
    appendLibraryLittleEndian(sampleRate, to: &data)
    appendLibraryLittleEndian(byteRate, to: &data)
    appendLibraryLittleEndian(blockAlign, to: &data)
    appendLibraryLittleEndian(bitsPerSample, to: &data)
    data.append(contentsOf: Array("data".utf8))
    appendLibraryLittleEndian(dataSize, to: &data)
    data.append(Data(repeating: 0, count: Int(dataSize)))
    return data
}

private func appendLibraryLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) {
        data.append(contentsOf: $0)
    }
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
