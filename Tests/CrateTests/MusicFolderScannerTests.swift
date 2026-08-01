import Foundation
import XCTest
@testable import Crate

@MainActor
final class MusicFolderScannerTests: XCTestCase {
    func testRecursiveScanImportsNestedAudioAndRejectsNestedSource() throws {
        let fixture = try MusicFolderFixture()
        defer { fixture.cleanup() }
        let nested = fixture.musicURL.appendingPathComponent("Artist/Album", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let audioURL = nested.appendingPathComponent("Song.wav")
        try makePCM16WAV(frameCount: 8_000).write(to: audioURL)
        let app = fixture.makeApp()

        XCTAssertEqual(app.addMusicFolders([fixture.musicURL]), 1)
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.library.count == 1
        })
        XCTAssertEqual(app.library.first?.fileURL?.standardizedFileURL.path, audioURL.standardizedFileURL.path)
        XCTAssertEqual(app.library.first?.sourceFolderId, app.musicFolders.first?.id)
        XCTAssertNotNil(app.library.first?.dateAdded)

        XCTAssertEqual(app.addMusicFolders([nested], startScan: false), 0)
        XCTAssertEqual(app.musicFolders.count, 1)
        XCTAssertEqual(app.toast, "所选位置与现有音乐文件夹重复")
    }

    func testRescanPreservesSongIdentityAcrossRenameAndRefreshesChangedFile() throws {
        let fixture = try MusicFolderFixture()
        defer { fixture.cleanup() }
        let originalURL = fixture.musicURL.appendingPathComponent("Original.wav")
        try makePCM16WAV(frameCount: 8_000).write(to: originalURL)
        let app = fixture.makeApp()
        app.addMusicFolders([fixture.musicURL])
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.library.count == 1
        })
        let originalId = try XCTUnwrap(app.library.first?.id)
        let originalDuration = try XCTUnwrap(app.library.first?.duration)

        let renamedURL = fixture.musicURL.appendingPathComponent("Renamed.wav")
        try FileManager.default.moveItem(at: originalURL, to: renamedURL)
        app.scanMusicFolders()
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle
                && app.library.first?.fileURL?.standardizedFileURL.path == renamedURL.standardizedFileURL.path
        })
        XCTAssertEqual(app.library.first?.id, originalId)

        Thread.sleep(forTimeInterval: 0.02)
        try makePCM16WAV(frameCount: 16_000).write(to: renamedURL)
        app.scanMusicFolders()
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && (app.library.first?.duration ?? 0) > originalDuration
        })
        XCTAssertEqual(app.library.first?.id, originalId)
    }

    func testRescanRemovesDeletedSongAndAllReferences() throws {
        let fixture = try MusicFolderFixture()
        defer { fixture.cleanup() }
        let audioURL = fixture.musicURL.appendingPathComponent("Delete.wav")
        try makePCM16WAV(frameCount: 8_000).write(to: audioURL)
        let app = fixture.makeApp()
        app.addMusicFolders([fixture.musicURL])
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.library.count == 1
        })
        let song = try XCTUnwrap(app.library.first)
        let group = try XCTUnwrap(app.createGroup(named: "测试分组"))
        app.addSong(song, to: group)
        app.player.addToQueue(song)
        XCTAssertTrue(app.playlists.first(where: { $0.id == group.id })?.songIds.contains(song.id) == true)
        XCTAssertTrue(app.player.manualQueue.contains(song.id))

        try FileManager.default.removeItem(at: audioURL)
        app.scanMusicFolders()
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.library.isEmpty
        })
        XCTAssertFalse(app.playlists.contains { $0.songIds.contains(song.id) })
        XCTAssertFalse(app.player.manualQueue.contains(song.id))
        XCTAssertTrue(app.albums.isEmpty)
    }

    func testUnavailableSourcePreservesSongsAndRemovingSourceKeepsRecords() throws {
        let fixture = try MusicFolderFixture()
        defer { fixture.cleanup() }
        let audioURL = fixture.musicURL.appendingPathComponent("Offline.wav")
        try makePCM16WAV(frameCount: 8_000).write(to: audioURL)
        let app = fixture.makeApp()
        app.addMusicFolders([fixture.musicURL])
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.library.count == 1
        })
        let songId = try XCTUnwrap(app.library.first?.id)
        let sourceId = try XCTUnwrap(app.musicFolders.first?.id)

        try FileManager.default.removeItem(at: fixture.musicURL)
        app.scanMusicFolders()
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            app.importPhase == .idle && app.toast?.contains("1 个文件夹无法访问") == true
        })
        XCTAssertEqual(app.library.map(\.id), [songId])

        app.removeMusicFolder(sourceId)
        XCTAssertTrue(app.musicFolders.isEmpty)
        XCTAssertEqual(app.library.map(\.id), [songId])
        XCTAssertNil(app.library.first?.sourceFolderId)
    }

    func testPersistedSourceRestoresAndScansAutomaticallyOnStartup() throws {
        let fixture = try MusicFolderFixture()
        defer { fixture.cleanup() }
        let firstApp = fixture.makeApp()
        XCTAssertEqual(firstApp.addMusicFolders([fixture.musicURL], startScan: false), 1)
        firstApp.flushPersistence()

        let audioURL = fixture.musicURL.appendingPathComponent("AddedBeforeRestart.wav")
        try makePCM16WAV(frameCount: 8_000).write(to: audioURL)
        let restartedApp = fixture.makeApp()

        XCTAssertEqual(restartedApp.musicFolders.count, 1)
        XCTAssertTrue(waitForMusicFolderCondition(timeout: 8) {
            restartedApp.importPhase == .idle && restartedApp.library.count == 1
        })
        XCTAssertEqual(
            restartedApp.library.first?.fileURL?.standardizedFileURL.path,
            audioURL.standardizedFileURL.path
        )
    }
}

@MainActor
private final class MusicFolderFixture {
    let rootURL: URL
    let musicURL: URL
    let storeURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crate-folder-tests-\(UUID().uuidString)", isDirectory: true)
        musicURL = rootURL.appendingPathComponent("Music", isDirectory: true)
        storeURL = rootURL.appendingPathComponent("Store", isDirectory: true)
        try FileManager.default.createDirectory(at: musicURL, withIntermediateDirectories: true)
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

private func makePCM16WAV(frameCount: Int) -> Data {
    let sampleRate: UInt32 = 8_000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * UInt32(blockAlign)
    let dataSize = UInt32(frameCount) * UInt32(blockAlign)
    var data = Data()
    data.append(contentsOf: Array("RIFF".utf8))
    appendLittleEndian(UInt32(36) + dataSize, to: &data)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    appendLittleEndian(UInt32(16), to: &data)
    appendLittleEndian(UInt16(1), to: &data)
    appendLittleEndian(channels, to: &data)
    appendLittleEndian(sampleRate, to: &data)
    appendLittleEndian(byteRate, to: &data)
    appendLittleEndian(blockAlign, to: &data)
    appendLittleEndian(bitsPerSample, to: &data)
    data.append(contentsOf: Array("data".utf8))
    appendLittleEndian(dataSize, to: &data)
    data.append(Data(repeating: 0, count: Int(dataSize)))
    return data
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) {
        data.append(contentsOf: $0)
    }
}

@MainActor
@discardableResult
private func waitForMusicFolderCondition(
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
