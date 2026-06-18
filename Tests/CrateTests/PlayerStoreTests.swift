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
}

@MainActor
final class AppStatePersistenceTests: XCTestCase {
    func testDecodeFailureDoesNotOverwriteExistingLibraryOnInitOrFlush() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
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
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        let fileInsteadOfDirectory = tempDir.appendingPathComponent("not-a-directory")
        try Data("not a directory".utf8).write(to: fileInsteadOfDirectory)
        AppState.storeDirectoryOverride = fileInsteadOfDirectory

        let app = AppState()

        XCTAssertTrue(waitForCondition { app.toast == "曲库保存失败，请检查磁盘权限或空间" })
    }
}

private final class FakeEngine: PlaybackEngine {
    var onFinished: (() -> Void)?
    var currentTime: Double = 0
    var playCalled = false

    func play() { playCalled = true }
    func pause() {}
    func seek(to time: Double) { currentTime = time }
    func setVolume(_ volume: Double) {}
    func stop() {}
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
