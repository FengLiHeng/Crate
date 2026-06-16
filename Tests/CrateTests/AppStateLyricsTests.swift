import Foundation
import XCTest
@testable import Crate

@MainActor
final class AppStateLyricsTests: XCTestCase {
    func testOpenLyricsLoadsCurrentSongSidecarFile() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)

        let musicDir = tempDir.appendingPathComponent("music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDir, withIntermediateDirectories: true)
        let audioURL = musicDir.appendingPathComponent("song.mp3")
        let lyricsURL = musicDir.appendingPathComponent("song.lrc")
        try Data().write(to: audioURL)
        try Data("[00:01.00]第一句".utf8).write(to: lyricsURL)

        let song = Song(id: "song", title: "Song", artist: "Artist", albumId: nil, duration: 120, fileURL: audioURL)
        let app = AppState()
        app.library = [song]
        app.player.currentId = song.id

        app.openLyricsForCurrentSong()

        XCTAssertEqual(app.lyricsPage?.songId, song.id)
        XCTAssertEqual(app.lyricsPage?.lyricsURL, lyricsURL)
        XCTAssertEqual(app.lyricsPage?.lyrics.lines.first?.text, "第一句")
    }

    func testOpenLyricsShowsToastWhenSidecarFileIsMissing() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)

        let audioURL = tempDir.appendingPathComponent("missing-lrc.mp3")
        try Data().write(to: audioURL)
        let song = Song(id: "song", title: "Song", artist: nil, albumId: nil, duration: 120, fileURL: audioURL)
        let app = AppState()
        app.library = [song]
        app.player.currentId = song.id

        app.openLyricsForCurrentSong()

        XCTAssertNil(app.lyricsPage)
        XCTAssertEqual(app.toast, "未找到同名歌词文件")
    }

    func testRefreshLyricsPageClosesWhenNextSongHasNoLyrics() throws {
        let tempDir = try makeTemporaryDirectory()
        defer {
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: tempDir)
        }
        AppState.storeDirectoryOverride = tempDir.appendingPathComponent("store", isDirectory: true)

        let firstURL = tempDir.appendingPathComponent("first.mp3")
        let secondURL = tempDir.appendingPathComponent("second.mp3")
        try Data().write(to: firstURL)
        try Data().write(to: secondURL)
        try Data("[00:01.00]第一句".utf8).write(to: tempDir.appendingPathComponent("first.lrc"))

        let first = Song(id: "first", title: "First", artist: nil, albumId: nil, duration: 120, fileURL: firstURL)
        let second = Song(id: "second", title: "Second", artist: nil, albumId: nil, duration: 120, fileURL: secondURL)
        let app = AppState()
        app.library = [first, second]
        app.player.currentId = first.id
        app.openLyricsForCurrentSong()

        app.player.currentId = second.id
        app.refreshLyricsPageForCurrentSong()

        XCTAssertNil(app.lyricsPage)
        XCTAssertEqual(app.toast, "未找到同名歌词文件")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crate-lyrics-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
