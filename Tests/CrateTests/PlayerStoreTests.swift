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

    func testBatchAddToQueueKeepsExistingPendingOrderAndOnlyAppendsNewSongs() {
        let current = Song(id: "current", title: "Current", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let upcoming = Song(id: "upcoming", title: "Upcoming", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let manual = Song(id: "manual", title: "Manual", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let firstNew = Song(id: "new-1", title: "New 1", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let secondNew = Song(id: "new-2", title: "New 2", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(
            uniqueKeysWithValues: [current, upcoming, manual, firstNew, secondNew].map { ($0.id, $0) }
        )
        let store = PlayerStore()
        store.songProvider = { songs[$0] }
        var toasts: [String] = []
        store.onToast = { toasts.append($0) }
        store.playFrom([current, upcoming], index: 0)
        store.playNextSong(manual)

        store.addToQueue([upcoming, manual, firstNew, current, secondNew, firstNew])

        XCTAssertEqual(store.manualQueue, [manual.id, firstNew.id, secondNew.id])
        XCTAssertEqual(store.upcomingIds, [upcoming.id])
        XCTAssertEqual(toasts.last, "已将 2 首歌曲添加到待播清单")
    }

    func testPendingEngineDoesNotAttachAfterStop() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let audioURL = tempDir.appendingPathComponent("pending.mp3")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0]), attributes: nil)

        let song = Song(id: "pending", title: "Pending", artist: nil, albumId: nil, duration: 10, fileURL: audioURL)
        let store = PlayerStore()
        let fakeEngine = FakeEngine()
        let buildCount = LockedCounter()
        let buildStarted = DispatchSemaphore(value: 0)
        let releaseBuild = DispatchSemaphore(value: 0)
        store.songProvider = { $0 == song.id ? song : nil }
        store.engineFactory = { _, _ in
            buildCount.increment()
            buildStarted.signal()
            _ = releaseBuild.wait(timeout: .now() + 2)
            return fakeEngine
        }

        store.playFrom([song], index: 0)
        XCTAssertTrue(store.isLoading)
        XCTAssertEqual(buildStarted.wait(timeout: .now() + 1), .success)
        store.togglePlay()
        XCTAssertEqual(buildCount.value, 1)

        store.stopPlayback()
        releaseBuild.signal()

        XCTAssertTrue(waitForCondition { store.currentId == nil && !store.isPlaying })
        XCTAssertFalse(store.isLoading)
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

    func testPreviousRestoresOriginWhenAllEarlierTracksAreUnavailable() {
        let first = Song(
            id: "first-missing",
            title: "First Missing",
            artist: nil,
            albumId: nil,
            duration: 10,
            fileURL: URL(fileURLWithPath: "/tmp/crate-tests-first-missing.mp3")
        )
        let second = Song(
            id: "second-missing",
            title: "Second Missing",
            artist: nil,
            albumId: nil,
            duration: 10,
            fileURL: URL(fileURLWithPath: "/tmp/crate-tests-second-missing.mp3")
        )
        let origin = Song(id: "origin", title: "Origin", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, origin].map { ($0.id, $0) })
        let store = PlayerStore()
        var missingIds: [String] = []
        var toasts: [String] = []
        store.songProvider = { songs[$0] }
        store.onMissing = { missingIds.append($0) }
        store.onToast = { toasts.append($0) }

        store.playFrom([first, second, origin], index: 2)
        store.prev()

        XCTAssertTrue(waitForCondition {
            store.currentId == origin.id && store.ctx.pos == 2 && store.isPlaying
        })
        XCTAssertEqual(Set(missingIds), Set([first.id, second.id]))
        XCTAssertFalse(toasts.contains("没有可播放的曲目"))
    }

    func testPreviousStopsWhenOriginAlsoBecomesUnavailable() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let originURL = tempDir.appendingPathComponent("origin.mp3")
        FileManager.default.createFile(atPath: originURL.path, contents: Data([0]), attributes: nil)

        let first = Song(
            id: "first-missing",
            title: "First Missing",
            artist: nil,
            albumId: nil,
            duration: 10,
            fileURL: tempDir.appendingPathComponent("first-missing.mp3")
        )
        let origin = Song(id: "origin", title: "Origin", artist: nil, albumId: nil, duration: 10, fileURL: originURL)
        let songs = Dictionary(uniqueKeysWithValues: [first, origin].map { ($0.id, $0) })
        let store = PlayerStore()
        let originEngine = FakeEngine()
        var toasts: [String] = []
        store.songProvider = { songs[$0] }
        store.engineFactory = { _, _ in originEngine }
        store.onToast = { toasts.append($0) }

        store.playFrom([first, origin], index: 1)
        XCTAssertTrue(waitForCondition { originEngine.playCalled })
        try FileManager.default.removeItem(at: originURL)

        store.prev()

        XCTAssertTrue(waitForCondition { store.currentId == nil })
        XCTAssertFalse(store.isPlaying)
        XCTAssertTrue(toasts.contains("没有可播放的曲目"))
    }

    func testSearchResultPreservesExistingQueueOrderAndRemovesDuplicate() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let searched = Song(id: "searched", title: "Searched", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let manual = Song(id: "manual", title: "Manual", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, searched, manual].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second, searched], index: 0)
        store.playNextSong(manual)
        store.playSearchResult(searched, fallbackContext: [first, second, searched])

        XCTAssertEqual(store.currentId, searched.id)
        XCTAssertTrue(store.isManual)
        XCTAssertEqual(store.manualQueue, [manual.id])
        XCTAssertEqual(store.ctx.ids, [first.id, second.id])
        XCTAssertEqual(store.upcomingIds, [second.id])

        store.next()
        XCTAssertEqual(store.currentId, manual.id)
        XCTAssertTrue(store.isManual)

        store.next()
        XCTAssertEqual(store.currentId, second.id)
        XCTAssertFalse(store.isManual)
    }

    func testFirstSearchResultPlaybackKeepsOriginalOrderWithoutSelectedSong() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let searched = Song(id: "searched", title: "Searched", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let fourth = Song(id: "fourth", title: "Fourth", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, searched, fourth].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playSearchResult(searched, fallbackContext: [first, second, searched, fourth])

        XCTAssertEqual(store.currentId, searched.id)
        XCTAssertTrue(store.isManual)
        XCTAssertEqual(store.ctx.pos, -1)
        XCTAssertEqual(store.upcomingIds, [first.id, second.id, fourth.id])

        store.next()
        XCTAssertEqual(store.currentId, first.id)
        XCTAssertFalse(store.isManual)
    }

    func testRegularPlaybackStillRotatesAndSwitchingGroupsReplacesContext() {
        let a1 = Song(id: "a1", title: "A1", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let a2 = Song(id: "a2", title: "A2", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let a3 = Song(id: "a3", title: "A3", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let b1 = Song(id: "b1", title: "B1", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let b2 = Song(id: "b2", title: "B2", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let b3 = Song(id: "b3", title: "B3", artist: nil, albumId: nil, duration: 10, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [a1, a2, a3, b1, b2, b3].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([a1, a2, a3], index: 1, rotateFromIndex: true)
        XCTAssertEqual(store.ctx.ids, [a2.id, a3.id, a1.id])

        store.playFrom([b1, b2, b3], index: 1, rotateFromIndex: true)
        XCTAssertEqual(store.currentId, b2.id)
        XCTAssertEqual(store.ctx.ids, [b2.id, b3.id, b1.id])
        XCTAssertTrue(store.manualQueue.isEmpty)
    }

    func testMoveManualQueueItemUpdatesPlaybackOrderAndRejectsInvalidIndices() {
        let current = Song(id: "current", title: "Current", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let third = Song(id: "third", title: "Third", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [current, first, second, third].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([current], index: 0)
        store.seek(to: 6)
        store.addToQueue(first)
        store.addToQueue(second)
        store.addToQueue(third)

        XCTAssertTrue(store.moveManualQueueItem(from: 2, to: 0))
        XCTAssertEqual(store.manualQueue, [third.id, first.id, second.id])
        XCTAssertEqual(store.currentId, current.id)
        XCTAssertEqual(store.progress, 6)

        XCTAssertFalse(store.moveManualQueueItem(from: -1, to: 0))
        XCTAssertFalse(store.moveManualQueueItem(from: 0, to: 3))
        XCTAssertFalse(store.moveManualQueueItem(from: 1, to: 1))
        XCTAssertEqual(store.manualQueue, [third.id, first.id, second.id])

        store.next()
        XCTAssertEqual(store.currentId, third.id)
        XCTAssertTrue(store.isManual)
    }

    func testMoveUpcomingItemPreservesCurrentPlaybackAndUpdatesNormalOrder() {
        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let third = Song(id: "third", title: "Third", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let fourth = Song(id: "fourth", title: "Fourth", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let songs = Dictionary(uniqueKeysWithValues: [first, second, third, fourth].map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songs[$0] }

        store.playFrom([first, second, third, fourth], index: 0)
        store.seek(to: 7)

        XCTAssertTrue(store.moveUpcomingItem(from: 2, to: 0))
        XCTAssertEqual(store.ctx.ids, [first.id, fourth.id, second.id, third.id])
        XCTAssertEqual(store.ctx.originalIds, store.ctx.ids)
        XCTAssertEqual(store.ctx.pos, 0)
        XCTAssertEqual(store.currentId, first.id)
        XCTAssertEqual(store.progress, 7)

        XCTAssertFalse(store.moveUpcomingItem(from: -1, to: 0))
        XCTAssertFalse(store.moveUpcomingItem(from: 0, to: 3))
        XCTAssertFalse(store.moveUpcomingItem(from: 1, to: 1))
        XCTAssertEqual(store.ctx.ids, [first.id, fourth.id, second.id, third.id])

        store.next()
        XCTAssertEqual(store.currentId, fourth.id)
        XCTAssertFalse(store.isManual)
    }

    func testMoveUpcomingItemInShuffleOnlyChangesEffectiveOrder() {
        let songs = (0..<5).map {
            Song(id: "song-\($0)", title: "Song \($0)", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        }
        let songsById = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        let store = PlayerStore()
        store.songProvider = { songsById[$0] }

        store.playFrom(songs, index: 2)
        store.toggleShuffle()
        let originalIds = store.ctx.originalIds
        let effectiveIds = store.ctx.ids
        let currentId = store.currentId

        XCTAssertTrue(store.moveUpcomingItem(from: 0, to: 3))
        XCTAssertNotEqual(store.ctx.ids, effectiveIds)
        XCTAssertEqual(store.ctx.originalIds, originalIds)
        XCTAssertEqual(store.currentId, currentId)
        XCTAssertEqual(store.ctx.pos, 0)

        store.toggleShuffle()
        XCTAssertFalse(store.shuffle)
        XCTAssertEqual(store.ctx.ids, originalIds)
        XCTAssertEqual(store.currentId, currentId)
        XCTAssertEqual(store.ctx.pos, originalIds.firstIndex(of: currentId!)!)
    }

    func testReorderedQueuesRestoreFromPlaybackMemory() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let memoryURL = tempDir.appendingPathComponent("playback.json")
        let current = Song(id: "current", title: "Current", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let upcomingFirst = Song(id: "upcoming-first", title: "Upcoming First", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let upcomingSecond = Song(id: "upcoming-second", title: "Upcoming Second", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let manualFirst = Song(id: "manual-first", title: "Manual First", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let manualSecond = Song(id: "manual-second", title: "Manual Second", artist: nil, albumId: nil, duration: 20, fileURL: nil)
        let songs = [current, upcomingFirst, upcomingSecond, manualFirst, manualSecond]
        let songsById = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })

        let source = PlayerStore()
        source.songProvider = { songsById[$0] }
        source.configurePlaybackMemory(url: memoryURL)
        source.playFrom([current, upcomingFirst, upcomingSecond], index: 0)
        source.addToQueue(manualFirst)
        source.addToQueue(manualSecond)
        XCTAssertTrue(source.moveManualQueueItem(from: 1, to: 0))
        XCTAssertTrue(source.moveUpcomingItem(from: 1, to: 0))
        source.flushPlaybackMemory()

        let restored = PlayerStore()
        restored.songProvider = { songsById[$0] }
        restored.configurePlaybackMemory(url: memoryURL)
        restored.restorePlaybackMemory(availableSongs: songsById)

        XCTAssertEqual(restored.currentId, current.id)
        XCTAssertEqual(restored.manualQueue, [manualSecond.id, manualFirst.id])
        XCTAssertEqual(restored.upcomingIds, [upcomingSecond.id, upcomingFirst.id])
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

private final class FakeEngine: PlaybackEngine, @unchecked Sendable {
    var onFinished: (@Sendable () -> Void)?
    var onFailed: (@Sendable () -> Void)?
    var currentTime: Double = 0
    var playCalled = false

    func play() { playCalled = true }
    func pause() {}
    func seek(to time: Double) { currentTime = time }
    func setVolume(_ volume: Double) {}
    func stop() {}
    func fail() { onFailed?() }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
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
