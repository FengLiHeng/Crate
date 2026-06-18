import AppKit
import XCTest
@testable import Crate

@MainActor
final class CrateAppDelegateTests: XCTestCase {
    func testDockMenuShowsPauseWhenTrackIsPlaying() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let delegate = CrateAppDelegate()
        delegate.bind(appState: fixture.app)
        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)

        let menu = try XCTUnwrap(delegate.applicationDockMenu(NSApplication.shared))

        XCTAssertEqual(menu.items.map(\.title), ["上一首", "暂停", "下一首"])
        XCTAssertTrue(menu.items.allSatisfy(\.isEnabled))
    }

    func testDockMenuShowsPlayWhenTrackIsPaused() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let delegate = CrateAppDelegate()
        delegate.bind(appState: fixture.app)
        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)
        fixture.app.player.togglePlay()

        let menu = try XCTUnwrap(delegate.applicationDockMenu(NSApplication.shared))

        XCTAssertEqual(menu.items.map(\.title), ["上一首", "播放", "下一首"])
        XCTAssertTrue(menu.items.allSatisfy(\.isEnabled))
    }

    func testDockMenuDisablesPlaybackItemsWithoutCurrentSong() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let delegate = CrateAppDelegate()
        delegate.bind(appState: fixture.app)

        let menu = try XCTUnwrap(delegate.applicationDockMenu(NSApplication.shared))

        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertEqual(menu.items.map(\.title), ["上一首", "播放", "下一首"])
        XCTAssertTrue(menu.items.allSatisfy { !$0.isEnabled })
    }

    func testDockNextUsesManualQueueFirst() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let delegate = CrateAppDelegate()
        delegate.bind(appState: fixture.app)
        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)
        fixture.app.player.playNextSong(fixture.manual)

        delegate.nextTrack()

        XCTAssertTrue(waitForCondition { fixture.app.player.currentId == fixture.manual.id })
    }

    func testDockPreviousRestartsTrackAfterProgressThreshold() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let delegate = CrateAppDelegate()
        delegate.bind(appState: fixture.app)
        fixture.app.player.playFrom([fixture.first, fixture.second], index: 0)
        fixture.app.player.seek(to: 4)

        delegate.previousTrack()

        XCTAssertTrue(waitForCondition { fixture.app.player.currentId == fixture.first.id && fixture.app.player.progress == 0 })
    }
}

private struct AppDelegateFixture {
    var app: AppState
    var first: Song
    var second: Song
    var manual: Song
    var tempDir: URL

    func cleanup() {
        app.player.stopPlayback()
        AppState.storeDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
    }
}

@MainActor
private func makeFixture() throws -> AppDelegateFixture {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-app-delegate-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)

    let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 20, fileURL: nil)
    let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 20, fileURL: nil)
    let manual = Song(id: "manual", title: "Manual", artist: nil, albumId: nil, duration: 20, fileURL: nil)
    let app = AppState()
    app.library = [first, second, manual]

    return AppDelegateFixture(app: app, first: first, second: second, manual: manual, tempDir: tempDir)
}

@MainActor
@discardableResult
private func waitForCondition(
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
