import Foundation

// 示例曲库数据，移植自 docs/设计材料/music-data.js（虚构，中英混合）
enum SampleData {
    static let albums: [Album] = [
        Album(id: "a1", title: "城南旧事", artist: "陈晚秋", year: 2023, h1: 250, h2: 290),
        Album(id: "a2", title: "Neon Harbor", artist: "The Glass Tides", year: 2024, h1: 200, h2: 250),
        Album(id: "a3", title: "山海间", artist: "苏屿", year: 2022, h1: 150, h2: 190),
        Album(id: "a4", title: "Paper Planes", artist: "Ivy Marlowe", year: 2021, h1: 20, h2: 55),
        Album(id: "a5", title: "电台午夜", artist: "林一帆", year: 2024, h1: 280, h2: 320),
        Album(id: "a6", title: "Driftwood", artist: "Cedar North", year: 2023, h1: 95, h2: 135),
        Album(id: "a7", title: "候鸟", artist: "周野", year: 2020, h1: 230, h2: 205),
        Album(id: "a8", title: "Velvet Hours", artist: "Mona Quinn", year: 2025, h1: 335, h2: 10),
    ]

    static let songs: [Song] = [
        Song(id: "s01", title: "城南旧事", artist: nil, albumId: "a1", duration: 252, fileURL: nil),
        Song(id: "s02", title: "巷口的猫", artist: nil, albumId: "a1", duration: 198, fileURL: nil),
        Song(id: "s03", title: "旧书店", artist: nil, albumId: "a1", duration: 224, fileURL: nil),
        Song(id: "s04", title: "晚来风急", artist: nil, albumId: "a1", duration: 276, fileURL: nil),
        Song(id: "s05", title: "Neon Harbor", artist: nil, albumId: "a2", duration: 235, fileURL: nil),
        Song(id: "s06", title: "Midnight Ferry", artist: nil, albumId: "a2", duration: 261, fileURL: nil),
        Song(id: "s07", title: "Salt & Static", artist: nil, albumId: "a2", duration: 189, fileURL: nil),
        Song(id: "s08", title: "Lighthouse", artist: nil, albumId: "a2", duration: 304, fileURL: nil),
        Song(id: "s09", title: "山海间", artist: nil, albumId: "a3", duration: 287, fileURL: nil),
        Song(id: "s10", title: "雾起时", artist: nil, albumId: "a3", duration: 213, fileURL: nil),
        Song(id: "s11", title: "南方以南", artist: nil, albumId: "a3", duration: 246, fileURL: nil),
        Song(id: "s12", title: "Paper Planes", artist: nil, albumId: "a4", duration: 192, fileURL: nil),
        Song(id: "s13", title: "Amber Afternoon", artist: nil, albumId: "a4", duration: 228, fileURL: nil),
        Song(id: "s14", title: "Slow Honey", artist: nil, albumId: "a4", duration: 257, fileURL: nil),
        Song(id: "s15", title: "电台午夜", artist: nil, albumId: "a5", duration: 241, fileURL: nil),
        Song(id: "s16", title: "失眠便利店", artist: nil, albumId: "a5", duration: 209, fileURL: nil),
        Song(id: "s17", title: "凌晨三点的出租车", artist: nil, albumId: "a5", duration: 295, fileURL: nil),
        Song(id: "s18", title: "Driftwood", artist: nil, albumId: "a6", duration: 218, fileURL: nil),
        Song(id: "s19", title: "Quiet Rivers", artist: nil, albumId: "a6", duration: 263, fileURL: nil),
        Song(id: "s20", title: "Pinelight", artist: nil, albumId: "a6", duration: 184, fileURL: nil),
        Song(id: "s21", title: "候鸟", artist: nil, albumId: "a7", duration: 312, fileURL: nil),
        Song(id: "s22", title: "北方的信", artist: nil, albumId: "a7", duration: 236, fileURL: nil),
        Song(id: "s23", title: "Velvet Hours", artist: nil, albumId: "a8", duration: 247, fileURL: nil),
        Song(id: "s24", title: "Garnet", artist: nil, albumId: "a8", duration: 202, fileURL: nil),
        Song(id: "s25", title: "Last Call", artist: nil, albumId: "a8", duration: 274, fileURL: nil),
    ]

    static let playlists: [Playlist] = [
        Playlist(id: "p1", name: "通勤路上", songIds: ["s02", "s05", "s12", "s18", "s22", "s24"]),
        Playlist(id: "p2", name: "深夜写代码", songIds: ["s15", "s16", "s17", "s19", "s08", "s10"]),
        Playlist(id: "p3", name: "周末清晨", songIds: ["s13", "s14", "s20", "s03", "s09"]),
        Playlist(id: "p4", name: "健身节奏", songIds: ["s07", "s05", "s23", "s25", "s04"]),
    ]
}
