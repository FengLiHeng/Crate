## 1. 实现

- [x] 1.1 在歌曲右键菜单中为导入歌曲新增“移到废纸篓并移除记录…”操作
- [x] 1.2 删除前显示确认提示，并将文件移到废纸篓
- [x] 1.3 删除后同步移除资料库记录、分组引用、播放队列、播放上下文、选中态和失效标记

## 2. 验证

- [x] 2.1 运行 openspec validate delete-local-song-file
- [x] 2.2 运行 swift build
- [x] 2.3 运行 Scripts/bundle.sh 生成 build/Crate.app
