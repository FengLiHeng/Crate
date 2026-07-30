import XCTest
@testable import Crate

@MainActor
final class ScreenshotModeTests: XCTestCase {
    func testParsesCompleteScreenshotArguments() throws {
        let configuration = try XCTUnwrap(ScreenshotLaunchConfiguration.parse(arguments: [
            "Crate",
            "--screenshot-scene", "light-queue",
            "--screenshot-ready-file", "/tmp/crate-ready",
            "--screenshot-store", "/tmp/crate-store",
        ]))

        XCTAssertEqual(configuration.scene, .lightQueue)
        XCTAssertEqual(configuration.readyFileURL.path, "/tmp/crate-ready")
        XCTAssertEqual(configuration.storeDirectoryURL.path, "/tmp/crate-store")
    }

    func testRejectsIncompleteOrUnknownScreenshotArguments() {
        XCTAssertNil(ScreenshotLaunchConfiguration.parse(arguments: [
            "Crate", "--screenshot-scene", "unknown",
        ]))
        XCTAssertNil(ScreenshotLaunchConfiguration.parse(arguments: [
            "Crate", "--screenshot-scene", "light-home",
        ]))
    }

    func testScreenshotSceneUsesFixtureWithoutWritingLibrary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("crate-screenshot-tests-\(UUID().uuidString)", isDirectory: true)
        AppState.storeDirectoryOverride = directory
        defer {
            AppState.storeDirectoryOverride = nil
            try? FileManager.default.removeItem(at: directory)
        }

        let app = AppState(screenshotScene: .lightQueue)
        app.flushPersistence()

        XCTAssertEqual(app.theme, .light)
        XCTAssertEqual(app.library.count, SampleData.songs.count)
        XCTAssertTrue(app.queueOpen)
        XCTAssertNotNil(app.player.currentId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.json").path))
    }
}
