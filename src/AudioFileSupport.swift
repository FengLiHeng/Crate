import Foundation
import AVFoundation
import UniformTypeIdentifiers

enum AudioFileSupport {
    static let extensionList = ["mp3", "m4a", "flac", "wav", "aac", "aiff"]
    static let extensions = Set(extensionList)

    static var contentTypes: [UTType] {
        var types = [UTType.audio]
        for ext in extensionList {
            guard let type = UTType(filenameExtension: ext), !types.contains(type) else { continue }
            types.append(type)
        }
        return types
    }

    static func isSupportedExtension(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }

    static func canDecode(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              isSupportedExtension(url) else { return false }
        if (try? AVAudioPlayer(contentsOf: url)) != nil { return true }
        return canPlayWithAVAsset(at: url)
    }

    static func canPlayWithAVAsset(at url: URL, timeout: TimeInterval = 5) -> Bool {
        let result = PlayableProbeResult()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            let playable = (try? await AVURLAsset(url: url).load(.isPlayable)) ?? false
            result.set(playable)
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else { return false }
        return result.value
    }
}

private final class PlayableProbeResult: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func set(_ value: Bool) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}
