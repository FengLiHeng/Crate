import Foundation

struct Album: Identifiable, Codable, Hashable {
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

struct Song: Identifiable, Codable, Hashable {
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
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var songIds: [String]
}
