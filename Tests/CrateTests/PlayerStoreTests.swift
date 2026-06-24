import Foundation
import XCTest
@testable import Crate

@MainActor
final class PlayerStoreTests: XCTestCase {
    func testAllUnplayableTracksStopAndReportNoPlayableTracks() {
        let store = PlayerStore()
        let song = Song(
            id: "missing",
            title: "Missing",
            artist: nil,
            albumId: nil,
            duration: 12,
            fileURL: URL(fileURLWithPath: "/tmp/crate-tests-missing-file.mp3")
        )
        var toasts: [String] = []
        var missingIds: [String] = []
        store.songProvider = { $0 == song.id ? song : nil }
        store.onToast = { toasts.append($0) }
        store.onMissing = { missingIds.append($0) }

        store.playFrom([song], index: 0)

        XCTAssertTrue(waitForCondition { store.currentId == nil })
        XCTAssertEqual(missingIds, [song.id])
        XCTAssertTrue(toasts.contains("没有可播放的曲目"))
        XCTAssertFalse(store.isPlaying)
    }

    func testImmediatePlayNextReturnsToContextNextTrack() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let manual = Song(id: "manual", title: "Manual", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, manual].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second], index: 0)
        store.playSongNow(manual)
        store.next()

        XCTAssertEqual(store.currentId, second.id)
        XCTAssertFalse(store.isManual)
        XCTAssertTrue(store.isPlaying)
    }

    func testPlayFromDeduplicatesContextAndKeepsSelectedSong() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let third = Song(id: "third", title: "Third", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, third].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second, first, third], index: 3)

        XCTAssertEqual(store.currentId, third.id)
        XCTAssertEqual(store.ctx.ids, [first.id, second.id, third.id])
        XCTAssertEqual(store.ctx.originalIds, [first.id, second.id, third.id])
        XCTAssertEqual(store.ctx.pos, 2)
        XCTAssertTrue(store.manualQueue.isEmpty)
    }

    func testPlayNextSongMovesUpcomingTrackToManualQueueWithoutDuplicate() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let third = Song(id: "third", title: "Third", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, third].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second, third], index: 0)
        store.playNextSong(third)

        XCTAssertEqual(store.manualQueue, [third.id])
        XCTAssertEqual(store.upcomingIds, [second.id])
        XCTAssertEqual(store.ctx.originalIds, [first.id, second.id])
    }

    func testAddToQueueRepositionsExistingManualTrackWithoutDuplicate() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let third = Song(id: "third", title: "Third", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, third].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second, third], index: 0)
        store.playNextSong(second)
        store.addToQueue(second)

        XCTAssertEqual(store.manualQueue, [second.id])
        XCTAssertEqual(store.upcomingIds, [third.id])
    }

    func testPendingEngineDoesNotAttachAfterStop() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let audioURL = tempDir.appendingPathComponent("pending.mp3")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0]), attributes: nil)

        let song = Song(id: "pending", title: "Pending", artist: nil, albumId: nil, duration: 10, fileURL: audioURL)
        let store = PlayerStore()
        let fakeEngine = FakeEngine()
        let buildStarted = DispatchSemaphore(value: 0)
        let releaseBuild = DispatchSemaphore(value: 0)
        store.songProvider = { $0 == song.id ? song : nil }
        store.engineBuildQueue = DispatchQueue(label: "crate-tests-engine-build")
        store.engineFactory = { _, _ in
            buildStarted.signal()
            _ = releaseBuild.wait(timeout: .now() + 2)
            return fakeEngine
        }

        store.playFrom([song], index: 0)
        XCTAssertEqual(buildStarted.wait(timeout: .now() + 1), .success)

        store.stopPlayback()
        releaseBuild.signal()

        XCTAssertTrue(waitForCondition { store.currentId == nil && !store.isPlaying })
        XCTAssertFalse(fakeEngine.playCalled)
    }

    func testEngineFailureMarksTrackMissingAndSkipsForward() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let firstURL = tempDir.appendingPathComponent("first.mp3")
        let secondURL = tempDir.appendingPathComponent("second.mp3")
        FileManager.default.createFile(atPath: firstURL.path, contents: Data([0]), attributes: nil)
        FileManager.default.createFile(atPath: secondURL.path, contents: Data([0]), attributes: nil)

        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: firstURL)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: secondURL)
        let songs = Dictionary(uniqueKeysWithValues: [first, second].map { ($0.id, $0) })
        let firstEngine = FakeEngine()
        let secondEngine = FakeEngine()
        var toasts: [String] = []
        var missingIds: [String] = []

        let store = PlayerStore()
        store.songProvider = { songs[$0] }
        store.onToast = { toasts.append($0) }
        store.onMissing = { missingIds.append($0) }
        store.engineBuildQueue = DispatchQueue(label: "crate-tests-engine-failure-build")
        store.engineFactory = { url, _ in
            url == firstURL ? firstEngine : secondEngine
        }

        store.playFrom([first, second], index: 0)
        XCTAssertTrue(waitForCondition { store.currentId == first.id && firstEngine.playCalled })

        firstEngine.fail()

        XCTAssertTrue(waitForCondition { store.currentId == second.id && secondEngine.playCalled })
        XCTAssertEqual(missingIds, [first.id])
        XCTAssertTrue(toasts.contains("「First」的文件不可用，已跳过"))
    }
}

@MainActor
final class AppStatePersistenceTests: XCTestCase {
    func testDecodeFailureDoesNotOverwriteExistingLibraryOnInitOrFlush() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.stripsBundledSampleDataOverride = nil
        AppState.storeDirectoryOverride = tempDir
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("library.json")
        let invalidData = Data("not valid json".utf8)
        try invalidData.write(to: storeURL)

        let app = AppState()
        app.flushPersistence()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(try Data(contentsOf: storeURL), invalidData)
        XCTAssertEqual(app.library.count, 0)
        XCTAssertEqual(app.toast, "曲库读取失败，已暂时以空资料库启动")
    }

    func testPersistenceWriteFailureShowsToast() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        let fileInsteadOfDirectory = tempDir.appendingPathComponent("not-a-directory")
        try Data("not a directory".utf8).write(to: fileInsteadOfDirectory)
        AppState.storeDirectoryOverride = fileInsteadOfDirectory

        let app = AppState()

        XCTAssertTrue(waitForCondition { app.toast == "曲库保存失败，请检查磁盘权限或空间" })
    }

    func testReleaseLoadStripsPersistedBundledSampleData() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.stripsBundledSampleDataOverride = true
        AppState.storeDirectoryOverride = tempDir
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let storeURL = tempDir.appendingPathComponent("library.json")
        try writeLibrary(
            albums: SampleData.albums,
            songs: SampleData.songs,
            playlists: SampleData.playlists,
            to: storeURL
        )

        let app = AppState()
        app.flushPersistence()

        XCTAssertEqual(app.albums.count, 0)
        XCTAssertEqual(app.library.count, 0)
        XCTAssertEqual(app.playlists.filter { $0.id != AppState.favoritesGroupId }.count, 0)
        XCTAssertTrue(waitForCondition {
            (try? Data(contentsOf: storeURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0["songs"] as? [Any] }?.isEmpty == true
        })
    }

    func testReleaseLoadStripsArbitraryVirtualSongs() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.stripsBundledSampleDataOverride = true
        AppState.storeDirectoryOverride = tempDir
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let songs = [
            Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 20, fileURL: nil),
            Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 20, fileURL: nil),
            Song(id: "manual", title: "Manual", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        ]
        let storeURL = tempDir.appendingPathComponent("library.json")
        try writeLibrary(albums: [], songs: songs, playlists: [], to: storeURL)

        let app = AppState()
        app.flushPersistence()

        XCTAssertEqual(app.library.count, 0)
        XCTAssertTrue(waitForCondition {
            (try? Data(contentsOf: storeURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0["songs"] as? [Any] }?.isEmpty == true
        })
    }

    func testReleaseLoadKeepsUserImportedSongs() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.stripsBundledSampleDataOverride = true
        AppState.storeDirectoryOverride = tempDir
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let audioURL = tempDir.appendingPathComponent("song.mp3")
        try Data().write(to: audioURL)
        let userSong = Song(id: "user-song", title: "User Song", artist: nil, albumId: nil, duration: 12, fileURL: audioURL)
        try writeLibrary(albums: [], songs: [userSong], playlists: [], to: tempDir.appendingPathComponent("library.json"))

        let app = AppState()

        XCTAssertEqual(app.library, [userSong])
    }

    func testAsyncPersistenceUsesStoreDirectoryCapturedAtInitialization() throws {
        let firstDir = try makeTemporaryDirectory()
        let secondDir = try makeTemporaryDirectory()
        defer {
            AppState.stripsBundledSampleDataOverride = nil
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: firstDir)
            try? FileManager.default.removeItem(at: secondDir)
        }
        AppState.stripsBundledSampleDataOverride = false
        AppState.storeDirectoryOverride = firstDir
        let app = AppState()
        let song = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 20, fileURL: nil)

        app.library = [song]
        AppState.storeDirectoryOverride = secondDir

        let firstStoreURL = firstDir.appendingPathComponent("library.json")
        let secondStoreURL = secondDir.appendingPathComponent("library.json")
        XCTAssertTrue(waitForCondition {
            (try? Data(contentsOf: firstStoreURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0["songs"] as? [[String: Any]] }?.first?["id"] as? String == song.id
        })
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondStoreURL.path))
    }
}

private final class FakeEngine: PlaybackEngine {
    var onFinished: (() -> Void)?
    var onFailed: (() -> Void)?
    var currentTime: Double = 0
    var playCalled = false

    func play() { playCalled = true }
    func pause() {}
    func seek(to time: Double) { currentTime = time }
    func setVolume(_ volume: Double) {}
    func stop() {}
    func fail() { onFailed?() }
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

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeLibrary(albums: [Album], songs: [Song], playlists: [Playlist], to url: URL) throws {
    let payload: [String: Any] = [
        "albums": albums.map { album in
            [
                "id": album.id,
                "title": album.title,
                "artist": album.artist,
                "year": album.year,
                "h1": album.h1,
                "h2": album.h2
            ]
        },
        "songs": songs.map { song in
            [
                "id": song.id,
                "title": song.title,
                "artist": song.artist as Any,
                "albumId": song.albumId as Any,
                "duration": song.duration,
                "fileURL": song.fileURL?.absoluteString as Any
            ]
        },
        "playlists": playlists.map { playlist in
            [
                "id": playlist.id,
                "name": playlist.name,
                "songIds": playlist.songIds
            ]
        }
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    try data.write(to: url)
}
