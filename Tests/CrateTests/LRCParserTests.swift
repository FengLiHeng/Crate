import Foundation
import XCTest
@testable import Crate

final class LRCParserTests: XCTestCase {
    func testParsesMultipleTimestampsOnOneLine() throws {
        let lyrics = try LRCParser.parse("[00:10.00][00:20.00]重复歌词")

        XCTAssertEqual(lyrics.lines.map(\.time), [10.0, 20.0])
        XCTAssertEqual(lyrics.lines.map(\.text), ["重复歌词", "重复歌词"])
    }

    func testAppliesPositiveOffset() throws {
        let lyrics = try LRCParser.parse("""
        [offset:+500]
        [00:10.00]歌词
        """)

        XCTAssertEqual(try XCTUnwrap(lyrics.lines.first?.time), 10.5, accuracy: 0.0001)
    }

    func testAppliesNegativeOffsetWithoutGoingBelowZero() throws {
        let lyrics = try LRCParser.parse("""
        [offset:-2000]
        [00:01.00]开头
        [00:05.50]后续
        """)

        XCTAssertEqual(lyrics.lines[0].time, 0, accuracy: 0.0001)
        XCTAssertEqual(lyrics.lines[1].time, 3.5, accuracy: 0.0001)
    }

    func testIgnoresInvalidLinesAndKeepsMetadata() throws {
        let lyrics = try LRCParser.parse("""
        [ti:歌名]
        纯文本
        [00:03.5]一句
        """)

        XCTAssertEqual(lyrics.metadata["ti"], "歌名")
        XCTAssertEqual(lyrics.lines.count, 1)
        XCTAssertEqual(lyrics.lines[0].time, 3.5, accuracy: 0.0001)
        XCTAssertEqual(lyrics.lines[0].text, "一句")
    }

    func testSortsTimedLines() throws {
        let lyrics = try LRCParser.parse("""
        [00:20.00]第二句
        [00:10.00]第一句
        """)

        XCTAssertEqual(lyrics.lines.map(\.text), ["第一句", "第二句"])
    }

    func testThrowsForEmptyLyrics() {
        XCTAssertThrowsError(try LRCParser.parse("[ti:空]\n没有时间戳")) { error in
            XCTAssertEqual(error as? LRCParser.ParseError, .noTimedLines)
        }
    }

    func testDecodesUTF16LyricsData() throws {
        let source = "[00:01.00]歌词"
        let data = try XCTUnwrap(source.data(using: .utf16LittleEndian))

        XCTAssertEqual(LRCFileReader.decode(data), source)
    }
}
