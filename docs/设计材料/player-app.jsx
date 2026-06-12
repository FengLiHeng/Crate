// 主应用:状态管理 + 播放逻辑 + 导入
const { useState, useEffect, useRef, useMemo, useCallback } = React;

function shuffleArr(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function App() {
  const data = window.MUSIC_DATA;
  const [theme, setTheme] = useState(() => localStorage.getItem('lmp-theme') || 'light');
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem('lmp-theme', theme);
  }, [theme]);

  const [library, setLibrary] = useState(data.songs);
  const [playlists, setPlaylists] = useState(data.playlists);
  const albumsById = useMemo(() => Object.fromEntries(data.albums.map((a) => [a.id, a])), []);
  const songsById = useMemo(() => Object.fromEntries(library.map((s) => [s.id, s])), [library]);

  const [view, setView] = useState({ type: 'library' });
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState(null);

  // ── 播放状态 ──
  const [currentId, setCurrentId] = useState(null);
  const [isManual, setIsManual] = useState(false); // 当前曲目来自插播队列
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [volume, setVolume] = useState(0.7);
  const [shuffle, setShuffle] = useState(false);
  const [repeat, setRepeat] = useState('off'); // off | all | one
  const [manualQueue, setManualQueue] = useState([]); // 插播 ids
  const [ctx, setCtx] = useState({ ids: [], originalIds: [], pos: -1 });
  const [queueOpen, setQueueOpen] = useState(false);
  const [menu, setMenu] = useState(null);
  const [toast, setToast] = useState(null);
  const [dragOver, setDragOver] = useState(false);
  const dragDepth = useRef(0);
  const toastTimer = useRef(null);

  const showToast = useCallback((msg) => {
    setToast(msg);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2200);
  }, []);

  const currentSong = currentId ? songsById[currentId] : null;
  const currentAlbum = currentSong && currentSong.albumId ? albumsById[currentSong.albumId] : null;

  // ── 从列表开始播放 ──
  const playFrom = useCallback((list, index, forceShuffle = false) => {
    const ids = list.map((s) => s.id);
    const useShuffle = forceShuffle || shuffle;
    if (forceShuffle && !shuffle) setShuffle(true);
    let ordered = ids, pos = index;
    if (useShuffle) {
      const startId = index >= 0 ? ids[index] : ids[Math.floor(Math.random() * ids.length)];
      ordered = [startId, ...shuffleArr(ids.filter((id) => id !== startId))];
      pos = 0;
    }
    setCtx({ ids: ordered, originalIds: ids, pos });
    setCurrentId(ordered[pos]);
    setIsManual(false);
    setProgress(0);
    setIsPlaying(true);
  }, [shuffle]);

  const playSongNow = useCallback((song) => {
    // 立即播放单曲:作为插播播放,不打乱原上下文
    setCurrentId(song.id);
    setIsManual(true);
    setProgress(0);
    setIsPlaying(true);
  }, []);

  const stopPlayback = useCallback(() => {
    setIsPlaying(false);
    setProgress(0);
  }, []);

  // ── 下一首 / 上一首 ──
  const next = useCallback(() => {
    if (manualQueue.length > 0) {
      const [head, ...rest] = manualQueue;
      setManualQueue(rest);
      setCurrentId(head);
      setIsManual(true);
      setProgress(0);
      setIsPlaying(true);
      return;
    }
    const { ids, pos } = ctx;
    if (!ids.length) { stopPlayback(); return; }
    let nextPos = isManual ? pos + 1 : pos + 1; // 插播结束后回到上下文
    if (nextPos >= ids.length) {
      if (repeat === 'all') nextPos = 0;
      else { setIsPlaying(false); setProgress(currentSong ? currentSong.duration : 0); return; }
    }
    setCtx((c) => ({ ...c, pos: nextPos }));
    setCurrentId(ids[nextPos]);
    setIsManual(false);
    setProgress(0);
    setIsPlaying(true);
  }, [manualQueue, ctx, repeat, isManual, currentSong, stopPlayback]);

  const prev = useCallback(() => {
    if (progress > 3 || isManual) { setProgress(0); return; }
    const { ids, pos } = ctx;
    if (pos > 0) {
      setCtx((c) => ({ ...c, pos: pos - 1 }));
      setCurrentId(ids[pos - 1]);
      setProgress(0);
      setIsPlaying(true);
    } else {
      setProgress(0);
    }
  }, [progress, isManual, ctx]);

  // ── 模拟播放进度 ──
  useEffect(() => {
    if (!isPlaying || !currentId) return;
    const t = setInterval(() => setProgress((p) => p + 0.25), 250);
    return () => clearInterval(t);
  }, [isPlaying, currentId]);

  const nextRef = useRef(next);
  nextRef.current = next;
  useEffect(() => {
    if (!currentSong || !isPlaying) return;
    if (progress >= currentSong.duration) {
      if (repeat === 'one') setProgress(0);
      else nextRef.current();
    }
  }, [progress, currentSong, isPlaying, repeat]);

  // ── 随机/循环 ──
  const toggleShuffle = useCallback(() => {
    setShuffle((on) => {
      const nv = !on;
      setCtx((c) => {
        if (!c.ids.length) return c;
        if (nv) {
          const cur = c.ids[c.pos];
          const after = shuffleArr(c.ids.filter((id, i) => i !== c.pos));
          return { ...c, ids: [cur, ...after], pos: 0 };
        }
        const curId = currentId && !isManual ? currentId : c.ids[c.pos];
        const p = Math.max(0, c.originalIds.indexOf(curId));
        return { ...c, ids: c.originalIds, pos: p };
      });
      return nv;
    });
  }, [currentId, isManual]);

  const cycleRepeat = useCallback(() => {
    setRepeat((r) => (r === 'off' ? 'all' : r === 'all' ? 'one' : 'off'));
  }, []);

  // ── 队列操作 ──
  const playNextSong = useCallback((song) => {
    setManualQueue((q) => [song.id, ...q]);
    showToast(`「${song.title}」将在下一首播放`);
  }, [showToast]);

  const addToQueue = useCallback((song) => {
    setManualQueue((q) => [...q, song.id]);
    showToast(`已将「${song.title}」添加到待播清单`);
  }, [showToast]);

  const clearQueue = useCallback(() => {
    setManualQueue([]);
    setCtx((c) => ({ ...c, ids: c.ids.slice(0, c.pos + 1), originalIds: c.ids.slice(0, c.pos + 1) }));
    showToast('已清空待播清单');
  }, [showToast]);

  const playManualAt = useCallback((i) => {
    setManualQueue((q) => {
      const id = q[i];
      setCurrentId(id);
      setIsManual(true);
      setProgress(0);
      setIsPlaying(true);
      return q.filter((_, idx) => idx !== i);
    });
  }, []);

  const playContextAt = useCallback((i) => {
    // i 是 upcoming 列表中的序号(相对 pos+1)
    setCtx((c) => {
      const newPos = c.pos + 1 + i;
      if (newPos < c.ids.length) {
        setCurrentId(c.ids[newPos]);
        setIsManual(false);
        setProgress(0);
        setIsPlaying(true);
        return { ...c, pos: newPos };
      }
      return c;
    });
  }, []);

  // ── 右键菜单动作 ──
  const handleMenuAction = useCallback((action) => {
    const song = menu && songsById[menu.songId];
    if (!song) return;
    switch (action.type) {
      case 'play': playSongNow(song); break;
      case 'playNext': playNextSong(song); break;
      case 'addQueue': addToQueue(song); break;
      case 'addToPlaylist': {
        const pl = playlists.find((p) => p.id === action.playlistId);
        if (!pl) break;
        if (pl.songIds.includes(song.id)) { showToast(`「${song.title}」已在「${pl.name}」中`); break; }
        setPlaylists((ps) => ps.map((p) => (p.id === pl.id ? { ...p, songIds: [...p.songIds, song.id] } : p)));
        showToast(`已添加到「${pl.name}」`);
        break;
      }
      case 'reveal': showToast('已在 Finder 中显示(演示)'); break;
      case 'remove': {
        setLibrary((l) => l.filter((s) => s.id !== song.id));
        setPlaylists((ps) => ps.map((p) => ({ ...p, songIds: p.songIds.filter((id) => id !== song.id) })));
        setManualQueue((q) => q.filter((id) => id !== song.id));
        setCtx((c) => {
          const curId = c.ids[c.pos];
          const ids = c.ids.filter((id) => id !== song.id);
          const originalIds = c.originalIds.filter((id) => id !== song.id);
          return { ids, originalIds, pos: curId === song.id ? Math.min(c.pos, ids.length - 1) : ids.indexOf(curId) };
        });
        if (currentId === song.id) { setCurrentId(null); setIsPlaying(false); setProgress(0); }
        showToast(`已从资料库中删除「${song.title}」`);
        break;
      }
    }
  }, [menu, songsById, playlists, currentId, playSongNow, playNextSong, addToQueue, showToast]);

  // ── 导入 ──
  const fileInput = useRef(null);
  const importFiles = useCallback((fileList) => {
    const files = [...fileList].filter((f) => /\.(mp3|m4a|flac|wav|aac|ogg|aiff)$/i.test(f.name) || (f.type && f.type.startsWith('audio')));
    if (!files.length) { showToast('未发现可导入的音频文件'); return; }
    const stamp = Date.now();
    const newSongs = files.map((f, i) => ({
      id: 'imp' + stamp + '-' + i,
      title: f.name.replace(/\.[^.]+$/, ''),
      artist: '未知艺人',
      albumId: null,
      duration: 160 + Math.floor(Math.random() * 140),
    }));
    setLibrary((l) => [...l, ...newSongs]);
    setView({ type: 'library' });
    showToast(`已导入 ${newSongs.length} 首歌曲`);
  }, [showToast]);

  // ── 拖拽导入 ──
  const onDragEnter = (e) => {
    if (![...e.dataTransfer.types].includes('Files')) return;
    e.preventDefault();
    dragDepth.current++;
    setDragOver(true);
  };
  const onDragOver = (e) => { e.preventDefault(); };
  const onDragLeave = (e) => {
    e.preventDefault();
    dragDepth.current = Math.max(0, dragDepth.current - 1);
    if (dragDepth.current === 0) setDragOver(false);
  };
  const onDrop = (e) => {
    e.preventDefault();
    dragDepth.current = 0;
    setDragOver(false);
    if (e.dataTransfer.files && e.dataTransfer.files.length) importFiles(e.dataTransfer.files);
  };

  // ── 空格播放/暂停 ──
  useEffect(() => {
    const onKey = (e) => {
      const tag = e.target.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA') return;
      if (e.code === 'Space') { e.preventDefault(); if (currentId) setIsPlaying((p) => !p); }
      else if (e.code === 'ArrowRight' && e.metaKey) { e.preventDefault(); nextRef.current(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [currentId]);

  // ── 当前视图歌曲 ──
  const viewPlaylist = view.type === 'playlist' ? playlists.find((p) => p.id === view.id) : null;
  const viewSongs = useMemo(() => {
    let list = view.type === 'playlist' && viewPlaylist
      ? viewPlaylist.songIds.map((id) => songsById[id]).filter(Boolean)
      : library;
    const q = search.trim().toLowerCase();
    if (q) {
      list = list.filter((s) => {
        const album = s.albumId ? albumsById[s.albumId] : null;
        const artist = s.artist || (album ? album.artist : '');
        return s.title.toLowerCase().includes(q) || artist.toLowerCase().includes(q) || (album && album.title.toLowerCase().includes(q));
      });
    }
    return list;
  }, [view, viewPlaylist, library, search, songsById, albumsById]);

  const totalDuration = viewSongs.reduce((acc, s) => acc + s.duration, 0);
  const viewTitle = view.type === 'library' ? '歌曲' : (viewPlaylist ? viewPlaylist.name : '');

  // 队列面板数据
  const manualSongs = manualQueue.map((id) => songsById[id]).filter(Boolean);
  const upcomingSongs = ctx.ids.slice(ctx.pos + 1).map((id) => songsById[id]).filter(Boolean);

  return (
    <div className="desktop">
      <div className="window" onDragEnter={onDragEnter} onDragOver={onDragOver} onDragLeave={onDragLeave} onDrop={onDrop}>
        <div className="main">
          <Sidebar view={view} setView={setView} playlists={playlists} albumsById={albumsById} songsById={songsById} />
          <section className="content" data-screen-label={view.type === 'library' ? '歌曲' : '歌单:' + viewTitle}>
            <header className="content-head">
              <div className="head-top">
                {view.type === 'playlist' && viewPlaylist ? (
                  <div className="head-id">
                    <PlaylistCover playlist={viewPlaylist} albumsById={albumsById} songsById={songsById} size={64} radius={10} />
                    <div>
                      <h1 className="head-title">{viewTitle}</h1>
                      <div className="head-sub">{viewSongs.length} 首歌曲 · {formatTotal(totalDuration)}</div>
                    </div>
                  </div>
                ) : (
                  <div className="head-id">
                    <div>
                      <h1 className="head-title">{viewTitle}</h1>
                      <div className="head-sub">{viewSongs.length} 首歌曲 · {formatTotal(totalDuration)}</div>
                    </div>
                  </div>
                )}
                <div className="head-tools">
                  <div className="search-field">
                    <Icon name="search" size={14} style={{ color: 'var(--text-3)' }} />
                    <input
                      type="text"
                      placeholder="搜索"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                    />
                    {search && <button className="icon-btn search-x" onClick={() => setSearch('')}><Icon name="x" size={12} /></button>}
                  </div>
                  <button className="icon-btn tool-btn" title="导入音乐文件" onClick={() => fileInput.current && fileInput.current.click()}>
                    <Icon name="plus" size={17} />
                  </button>
                  <button className="icon-btn tool-btn" title={theme === 'light' ? '切换深色模式' : '切换浅色模式'} onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
                    <Icon name={theme === 'light' ? 'moon' : 'sun'} size={17} />
                  </button>
                </div>
              </div>
              <div className="head-actions">
                <button className="btn btn-primary" disabled={!viewSongs.length} onClick={() => playFrom(viewSongs, 0)}>
                  <Icon name="play" size={14} /><span>播放</span>
                </button>
                <button className="btn" disabled={!viewSongs.length} onClick={() => playFrom(viewSongs, -1, true)}>
                  <Icon name="shuffle" size={14} /><span>随机播放</span>
                </button>
              </div>
            </header>
            <div className="table-scroll">
              <SongTable
                songs={viewSongs}
                albumsById={albumsById}
                currentId={currentId}
                isPlaying={isPlaying}
                selectedId={selectedId}
                onSelect={setSelectedId}
                onPlay={(s, i) => playFrom(viewSongs, i)}
                onMenu={(s, x, y) => setMenu({ songId: s.id, x, y })}
                emptyHint={search ? `没有与「${search}」匹配的结果` : '资料库是空的,拖入音频文件或点击 + 导入'}
              />
            </div>
          </section>
          <QueuePanel
            open={queueOpen}
            current={currentSong}
            manual={manualSongs}
            upcoming={upcomingSongs}
            albumsById={albumsById}
            isPlaying={isPlaying}
            onClose={() => setQueueOpen(false)}
            onClear={clearQueue}
            onPlayManual={playManualAt}
            onPlayContext={playContextAt}
            onRemoveManual={(i) => setManualQueue((q) => q.filter((_, idx) => idx !== i))}
          />
        </div>
        <PlayBar
          song={currentSong}
          album={currentAlbum}
          isPlaying={isPlaying}
          progress={progress}
          volume={volume}
          shuffle={shuffle}
          repeat={repeat}
          queueOpen={queueOpen}
          onToggle={() => currentId && setIsPlaying((p) => !p)}
          onPrev={prev}
          onNext={next}
          onSeek={(v) => setProgress(v)}
          onVolume={setVolume}
          onShuffle={toggleShuffle}
          onRepeat={cycleRepeat}
          onQueue={() => setQueueOpen((o) => !o)}
        />
        {dragOver && (
          <div className="drop-overlay">
            <div className="drop-box">
              <Icon name="note" size={40} style={{ color: 'var(--accent)' }} />
              <div className="drop-title">拖放以导入音乐</div>
              <div className="drop-sub">支持 MP3 / M4A / FLAC / WAV / AAC</div>
            </div>
          </div>
        )}
        {toast && <div className="toast">{toast}</div>}
        <input
          ref={fileInput}
          type="file"
          accept="audio/*,.mp3,.m4a,.flac,.wav,.aac,.ogg,.aiff"
          multiple
          style={{ display: 'none' }}
          onChange={(e) => { importFiles(e.target.files); e.target.value = ''; }}
        />
      </div>
      {menu && (
        <ContextMenu
          menu={menu}
          playlists={playlists}
          onAction={handleMenuAction}
          onClose={() => setMenu(null)}
        />
      )}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
