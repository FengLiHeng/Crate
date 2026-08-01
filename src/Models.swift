import Foundation
import UniformTypeIdentifiers

struct Album: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var artist: String
    var year: Int
    /// 导入音频内嵌封面；缺失时由 UI 使用统一占位符
    var artworkData: Data? = nil
    /// 封面占位符与播放条氛围色的两个 OKLCH 色相
    var h1: Double
    var h2: Double
}

struct Song: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    /// 为 nil 时回退到所属专辑的艺人，再回退"未知艺人"
    var artist: String?
    var albumId: String?
    var duration: Double
    /// 导入的真实文件路径；示例曲目为 nil（播放走模拟引擎）
    var fileURL: URL?
    /// 无专辑名但文件自带封面时保存歌曲级封面
    var artworkData: Data? = nil
    /// 由音乐文件夹扫描认领的来源；手工导入歌曲为 nil
    var sourceFolderId: String? = nil
    /// 同一文件系统内稳定的设备号与文件号，用于识别重命名和移动
    var fileIdentity: String? = nil
    /// 增量扫描签名；任一字段变化时重新读取元数据
    var fileModificationDate: Date? = nil
    var fileSize: Int64? = nil
    /// 首次加入 Crate 曲库的时间；历史曲库缺失时保持 nil
    var dateAdded: Date? = nil
}

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var songIds: [String]
}

struct MusicFolderSource: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var path: String
    var bookmarkData: Data?

    init(
        id: String = "folder-" + UUID().uuidString,
        name: String,
        path: String,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmarkData = bookmarkData
    }
}

enum SongDragPayload {
    static let contentType = UTType(exportedAs: "com.crate.song-ids", conformingTo: .data)
    static let typeIdentifier = contentType.identifier
}

enum PlaylistDragPayload {
    /// 分组排序只在应用内部发生，使用系统文本类型可获得最稳定的 macOS 拖放识别。
    /// DropDelegate 仍会通过当前拖动分组 ID 拒绝外部文本，因此不会误收普通文本。
    static let contentType = UTType.text
    static let typeIdentifier = contentType.identifier
}
