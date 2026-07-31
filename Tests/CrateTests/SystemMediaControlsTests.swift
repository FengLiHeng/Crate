import MediaPlayer
import XCTest
@testable import Crate

@MainActor
final class SystemMediaControlsTests: XCTestCase {
    func testPublishesMetadataAndPlaybackChangesThenClearsWithoutSong() throws {
        let fixture = try makeSystemMediaFixture()
        defer { fixture.cleanup() }
        let backend = FakeSystemMediaControlsBackend()
        let controls = SystemMediaControls(appState: fixture.app, backend: backend)
        defer { controls.stop() }

        XCTAssertNil(backend.lastSnapshot)

        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)
        XCTAssertTrue(waitForSystemMediaCondition {
            backend.lastSnapshot?.songId == fixture.first.id
                && backend.lastSnapshot?.playbackRate == 1
        })

        let snapshot = try XCTUnwrap(backend.lastSnapshot)
        XCTAssertEqual(snapshot.title, "第一首")
        XCTAssertEqual(snapshot.artist, "专辑艺人")
        XCTAssertEqual(snapshot.albumTitle, "测试专辑")
        XCTAssertEqual(snapshot.artworkData, fixture.artworkData)
        XCTAssertEqual(snapshot.duration, 20)

        fixture.app.player.seek(to: 8)
        fixture.app.player.togglePlay()
        XCTAssertTrue(waitForSystemMediaCondition {
            backend.lastSnapshot?.elapsedTime == 8
                && backend.lastSnapshot?.playbackRate == 0
        })

        fixture.app.player.stopPlayback()
        XCTAssertTrue(waitForSystemMediaCondition {
            backend.publishCount > 1 && backend.lastSnapshot == nil
        })
    }

    func testRoutesEverySupportedCommandThroughPlayerStoreSemantics() throws {
        let fixture = try makeSystemMediaFixture()
        defer { fixture.cleanup() }
        let backend = FakeSystemMediaControlsBackend()
        let controls = SystemMediaControls(appState: fixture.app, backend: backend)
        defer { controls.stop() }
        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)

        XCTAssertTrue(backend.send(.pause))
        XCTAssertFalse(fixture.app.player.isPlaying)
        XCTAssertTrue(backend.send(.play))
        XCTAssertTrue(fixture.app.player.isPlaying)
        XCTAssertTrue(backend.send(.togglePlayPause))
        XCTAssertFalse(fixture.app.player.isPlaying)

        XCTAssertTrue(backend.send(.seek(to: 7)))
        XCTAssertEqual(fixture.app.player.progress, 7)
        XCTAssertTrue(backend.send(.previous))
        XCTAssertEqual(fixture.app.player.currentId, fixture.first.id)
        XCTAssertEqual(fixture.app.player.progress, 0)

        XCTAssertTrue(backend.send(.next))
        XCTAssertEqual(fixture.app.player.currentId, fixture.second.id)
    }

    func testRejectsCommandsWithoutCurrentSong() throws {
        let fixture = try makeSystemMediaFixture()
        defer { fixture.cleanup() }
        let backend = FakeSystemMediaControlsBackend()
        let controls = SystemMediaControls(appState: fixture.app, backend: backend)
        defer { controls.stop() }

        XCTAssertFalse(backend.send(.play))
        XCTAssertFalse(backend.send(.pause))
        XCTAssertFalse(backend.send(.togglePlayPause))
        XCTAssertFalse(backend.send(.previous))
        XCTAssertFalse(backend.send(.next))
        XCTAssertFalse(backend.send(.seek(to: 10)))
        XCTAssertNil(fixture.app.player.currentId)
    }

    func testMediaPlayerBackendReturnsNoActionableItemWithoutPublishedSong() {
        let backend = MediaPlayerSystemMediaControlsBackend()
        var receivedCommands: [SystemMediaCommand] = []
        var shouldHandleCommand = false
        backend.start { command in
            receivedCommands.append(command)
            return shouldHandleCommand
        }
        defer { backend.stop() }

        XCTAssertEqual(backend.dispatch(.play), .noActionableNowPlayingItem)
        XCTAssertTrue(receivedCommands.isEmpty)

        backend.publish(SystemNowPlayingSnapshot(
            songId: "song",
            title: "标题",
            artist: "艺人",
            albumTitle: "专辑",
            artworkData: nil,
            duration: 10,
            elapsedTime: 0,
            playbackRate: 0
        ))
        XCTAssertEqual(backend.dispatch(.play), .noActionableNowPlayingItem)
        XCTAssertEqual(receivedCommands, [.play])

        shouldHandleCommand = true
        XCTAssertEqual(backend.dispatch(.play), .success)
        XCTAssertEqual(receivedCommands, [.play, .play])

        backend.publish(nil)
        XCTAssertEqual(backend.dispatch(.play), .noActionableNowPlayingItem)
    }
}

@MainActor
private final class FakeSystemMediaControlsBackend: SystemMediaControlsBackend {
    private var commandHandler: (@MainActor (SystemMediaCommand) -> Bool)?
    private(set) var snapshots: [SystemNowPlayingSnapshot?] = []
    private(set) var stopped = false

    var lastSnapshot: SystemNowPlayingSnapshot? {
        snapshots.last ?? nil
    }

    var publishCount: Int {
        snapshots.count
    }

    func start(commandHandler: @escaping @MainActor (SystemMediaCommand) -> Bool) {
        self.commandHandler = commandHandler
    }

    func publish(_ snapshot: SystemNowPlayingSnapshot?) {
        snapshots.append(snapshot)
    }

    func stop() {
        stopped = true
        commandHandler = nil
    }

    func send(_ command: SystemMediaCommand) -> Bool {
        commandHandler?(command) ?? false
    }
}

@MainActor
private struct SystemMediaFixture {
    var app: AppState
    var first: Song
    var second: Song
    var artworkData: Data
    var tempDirectory: URL

    func cleanup() {
        app.player.stopPlayback()
        AppState.storeDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}

@MainActor
private func makeSystemMediaFixture() throws -> SystemMediaFixture {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-system-media-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    AppState.storeDirectoryOverride = tempDirectory.appendingPathComponent("store", isDirectory: true)

    let artworkData = Data([1, 2, 3, 4])
    let album = Album(
        id: "album",
        title: "测试专辑",
        artist: "专辑艺人",
        year: 2026,
        artworkData: artworkData,
        h1: 20,
        h2: 40
    )
    let first = Song(
        id: "first",
        title: "第一首",
        artist: nil,
        albumId: album.id,
        duration: 20,
        fileURL: nil
    )
    let second = Song(
        id: "second",
        title: "第二首",
        artist: "歌曲艺人",
        albumId: nil,
        duration: 30,
        fileURL: nil
    )
    let app = AppState()
    app.albums = [album]
    app.library = [first, second]

    return SystemMediaFixture(
        app: app,
        first: first,
        second: second,
        artworkData: artworkData,
        tempDirectory: tempDirectory
    )
}

@MainActor
private func waitForSystemMediaCondition(
    timeout: TimeInterval = 1,
    interval: TimeInterval = 0.01,
    _ predicate: @escaping () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if predicate() { return true }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(interval))
    }
    return predicate()
}
