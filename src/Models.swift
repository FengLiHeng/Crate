import Foundation

struct Album: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var artist: String
    var year: Int
    /// 封面渐变的两个 OKLCH 色相（与设计稿 music-data.js 的 h1/h2 一致）
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
}

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var songIds: [String]
}
