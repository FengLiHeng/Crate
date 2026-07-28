import SwiftUI
import XCTest
@testable import Crate

final class ThemeModeTests: XCTestCase {
    func testSystemModeUsesSystemColorScheme() {
        XCTAssertEqual(AppThemeMode.system.resolvedTheme(systemColorScheme: .light), .light)
        XCTAssertEqual(AppThemeMode.system.resolvedTheme(systemColorScheme: .dark), .dark)
        XCTAssertNil(AppThemeMode.system.preferredColorScheme)
    }

    func testFixedModesIgnoreSystemColorScheme() {
        XCTAssertEqual(AppThemeMode.light.resolvedTheme(systemColorScheme: .dark), .light)
        XCTAssertEqual(AppThemeMode.dark.resolvedTheme(systemColorScheme: .light), .dark)
        XCTAssertEqual(AppThemeMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppThemeMode.dark.preferredColorScheme, .dark)
    }

    func testPersistedLegacyValuesRemainValidModes() {
        XCTAssertEqual(AppThemeMode(rawValue: "light"), .light)
        XCTAssertEqual(AppThemeMode(rawValue: "dark"), .dark)
    }
}
