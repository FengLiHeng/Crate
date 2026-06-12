// 示例曲库数据(虚构,中英混合)
window.MUSIC_DATA = (() => {
  const albums = [
    { id: 'a1', title: '城南旧事', artist: '陈晚秋', year: 2023, h1: 250, h2: 290 },
    { id: 'a2', title: 'Neon Harbor', artist: 'The Glass Tides', year: 2024, h1: 200, h2: 250 },
    { id: 'a3', title: '山海间', artist: '苏屿', year: 2022, h1: 150, h2: 190 },
    { id: 'a4', title: 'Paper Planes', artist: 'Ivy Marlowe', year: 2021, h1: 20, h2: 55 },
    { id: 'a5', title: '电台午夜', artist: '林一帆', year: 2024, h1: 280, h2: 320 },
    { id: 'a6', title: 'Driftwood', artist: 'Cedar North', year: 2023, h1: 95, h2: 135 },
    { id: 'a7', title: '候鸟', artist: '周野', year: 2020, h1: 230, h2: 205 },
    { id: 'a8', title: 'Velvet Hours', artist: 'Mona Quinn', year: 2025, h1: 335, h2: 10 },
  ];

  const songs = [
    { id: 's01', title: '城南旧事', albumId: 'a1', duration: 252 },
    { id: 's02', title: '巷口的猫', albumId: 'a1', duration: 198 },
    { id: 's03', title: '旧书店', albumId: 'a1', duration: 224 },
    { id: 's04', title: '晚来风急', albumId: 'a1', duration: 276 },
    { id: 's05', title: 'Neon Harbor', albumId: 'a2', duration: 235 },
    { id: 's06', title: 'Midnight Ferry', albumId: 'a2', duration: 261 },
    { id: 's07', title: 'Salt & Static', albumId: 'a2', duration: 189 },
    { id: 's08', title: 'Lighthouse', albumId: 'a2', duration: 304 },
    { id: 's09', title: '山海间', albumId: 'a3', duration: 287 },
    { id: 's10', title: '雾起时', albumId: 'a3', duration: 213 },
    { id: 's11', title: '南方以南', albumId: 'a3', duration: 246 },
    { id: 's12', title: 'Paper Planes', albumId: 'a4', duration: 192 },
    { id: 's13', title: 'Amber Afternoon', albumId: 'a4', duration: 228 },
    { id: 's14', title: 'Slow Honey', albumId: 'a4', duration: 257 },
    { id: 's15', title: '电台午夜', albumId: 'a5', duration: 241 },
    { id: 's16', title: '失眠便利店', albumId: 'a5', duration: 209 },
    { id: 's17', title: '凌晨三点的出租车', albumId: 'a5', duration: 295 },
    { id: 's18', title: 'Driftwood', albumId: 'a6', duration: 218 },
    { id: 's19', title: 'Quiet Rivers', albumId: 'a6', duration: 263 },
    { id: 's20', title: 'Pinelight', albumId: 'a6', duration: 184 },
    { id: 's21', title: '候鸟', albumId: 'a7', duration: 312 },
    { id: 's22', title: '北方的信', albumId: 'a7', duration: 236 },
    { id: 's23', title: 'Velvet Hours', albumId: 'a8', duration: 247 },
    { id: 's24', title: 'Garnet', albumId: 'a8', duration: 202 },
    { id: 's25', title: 'Last Call', albumId: 'a8', duration: 274 },
  ];

  const playlists = [
    { id: 'p1', name: '通勤路上', songIds: ['s02', 's05', 's12', 's18', 's22', 's24'] },
    { id: 'p2', name: '深夜写代码', songIds: ['s15', 's16', 's17', 's19', 's08', 's10'] },
    { id: 'p3', name: '周末清晨', songIds: ['s13', 's14', 's20', 's03', 's09'] },
    { id: 'p4', name: '健身节奏', songIds: ['s07', 's05', 's23', 's25', 's04'] },
  ];

  return { albums, songs, playlists };
})();
