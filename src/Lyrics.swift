import Foundation
import CoreFoundation

struct LyricLine: Identifiable, Hashable {
    let id: Int
    let time: Double
    let text: String
}

struct ParsedLyrics: Hashable {
    let lines: [LyricLine]
    let metadata: [String: String]
}

enum LRCParser {
    enum ParseError: Error, Equatable {
        case noTimedLines
    }

    private static let timestampPattern = #"\[(\d+):(\d{1,2})(?:\.(\d{1,3}))?\]"#
    private static let offsetPattern = #"\[offset:\s*([+-]?\d+)\]"#
    private static let metadataPattern = #"\[([A-Za-z]+):([^\]]*)\]"#

    static func parse(_ source: String) throws -> ParsedLyrics {
        let timestampRegex = try NSRegularExpression(pattern: timestampPattern)
        let offsetRegex = try NSRegularExpression(pattern: offsetPattern, options: [.caseInsensitive])
        let metadataRegex = try NSRegularExpression(pattern: metadataPattern)

        var rawLines: [(time: Double, text: String)] = []
        var metadata: [String: String] = [:]
        var offset: Double = 0

        for line in source.components(separatedBy: .newlines) {
            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)

            if let match = offsetRegex.firstMatch(in: line, range: fullRange),
               let value = substring(match, at: 1, in: line),
               let milliseconds = Double(value) {
                offset = milliseconds / 1000.0
                continue
            }

            let timestampMatches = timestampRegex.matches(in: line, range: fullRange)
            if timestampMatches.isEmpty {
                captureMetadata(from: line, regex: metadataRegex, into: &metadata)
                continue
            }

            let text = timestampRegex.stringByReplacingMatches(
                in: line,
                range: fullRange,
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)

            for match in timestampMatches {
                guard let time = timeValue(from: match, in: line, offset: offset) else { continue }
                rawLines.append((time, text))
            }
        }

        guard !rawLines.isEmpty else { throw ParseError.noTimedLines }

        let lines = rawLines
            .sorted { lhs, rhs in
                if lhs.time == rhs.time { return lhs.text < rhs.text }
                return lhs.time < rhs.time
            }
            .enumerated()
            .map { index, item in
                LyricLine(id: index, time: item.time, text: item.text)
            }

        return ParsedLyrics(lines: lines, metadata: metadata)
    }

    private static func captureMetadata(
        from line: String,
        regex: NSRegularExpression,
        into metadata: inout [String: String]
    ) {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let key = substring(match, at: 1, in: line)?.lowercased(),
              key != "offset",
              let value = substring(match, at: 2, in: line) else { return }
        metadata[key] = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func timeValue(from match: NSTextCheckingResult, in line: String, offset: Double) -> Double? {
        guard let minutesText = substring(match, at: 1, in: line),
              let secondsText = substring(match, at: 2, in: line),
              let minutes = Double(minutesText),
              let seconds = Double(secondsText) else { return nil }

        var fraction = 0.0
        if let fractionText = substring(match, at: 3, in: line), !fractionText.isEmpty,
           let fractionValue = Double(fractionText) {
            fraction = fractionValue / pow(10.0, Double(fractionText.count))
        }

        return max(0, minutes * 60 + seconds + fraction + offset)
    }

    private static func substring(_ match: NSTextCheckingResult, at index: Int, in line: String) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: line) else { return nil }
        return String(line[swiftRange])
    }
}

enum LRCFileReader {
    static func decode(_ data: Data) -> String? {
        let systemDefault = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding())
        )
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            systemDefault
        ]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding), isUsableDecodedString(string) {
                return string
            }
        }
        return nil
    }

    private static func isUsableDecodedString(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard string.contains("[") else { return false }
        let scalarCount = string.unicodeScalars.count
        guard scalarCount > 0 else { return false }
        let nulCount = string.unicodeScalars.filter { $0.value == 0 }.count
        return Double(nulCount) / Double(scalarCount) < 0.05
    }
}
