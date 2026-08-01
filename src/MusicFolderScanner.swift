import Foundation

struct ScannedAudioFile: Sendable, Equatable {
    var sourceId: String
    var url: URL
    var identity: String?
    var modificationDate: Date?
    var size: Int64?
}

enum MusicFolderScanner {
    struct EnumerationResult: Sendable {
        var source: MusicFolderSource
        var files: [ScannedAudioFile]
    }

    static func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    static func pathsOverlap(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsParts = canonicalURL(lhs).pathComponents
        let rhsParts = canonicalURL(rhs).pathComponents
        return lhsParts.starts(with: rhsParts) || rhsParts.starts(with: lhsParts)
    }

    static func makeSource(for url: URL) -> MusicFolderSource {
        let canonical = canonicalURL(url)
        let bookmark = try? canonical.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return MusicFolderSource(
            name: canonical.lastPathComponent.isEmpty ? canonical.path : canonical.lastPathComponent,
            path: canonical.path,
            bookmarkData: bookmark
        )
    }

    static func resolvedURL(for source: MusicFolderSource) -> URL? {
        if let bookmarkData = source.bookmarkData {
            var stale = false
            if let bookmarkedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return canonicalURL(bookmarkedURL)
            }
        }
        guard !source.path.isEmpty else { return nil }
        return canonicalURL(URL(fileURLWithPath: source.path, isDirectory: true))
    }

    static func enumerate(_ source: MusicFolderSource) throws -> EnumerationResult {
        guard let rootURL = resolvedURL(for: source) else {
            throw CocoaError(.fileNoSuchFile)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }

        let accessing = rootURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        var enumerationError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var files: [ScannedAudioFile] = []
        while let url = enumerator.nextObject() as? URL {
            guard AudioFileSupport.isSupportedExtension(url),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let device = (attributes?[.systemNumber] as? NSNumber)?.stringValue
            let inode = (attributes?[.systemFileNumber] as? NSNumber)?.stringValue
            let identity = device.flatMap { device in inode.map { "\(device):\($0)" } }
            files.append(ScannedAudioFile(
                sourceId: source.id,
                url: canonicalURL(url),
                identity: identity,
                modificationDate: values.contentModificationDate,
                size: values.fileSize.map(Int64.init)
            ))
        }
        if let enumerationError {
            throw enumerationError
        }
        files.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }

        var updatedSource = source
        updatedSource.path = rootURL.path
        updatedSource.name = rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent
        if updatedSource.bookmarkData == nil {
            updatedSource.bookmarkData = try? rootURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        return EnumerationResult(source: updatedSource, files: files)
    }
}
