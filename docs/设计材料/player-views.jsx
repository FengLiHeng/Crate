// 视图组件:侧边栏、歌曲表格、队列面板、右键菜单、播放条
const { useEffect: vUseEffect, useRef: vUseRef, useState: vUseState } = React;

// ───────────────────────── 侧边栏 ─────────────────────────
function Sidebar({ view, setView, playlists, albumsById, songsById }) {
  return (
    <aside className="sidebar" data-screen-label="侧边栏">
      <div className="traffic">
        <span className="tl tl-r"></span><span className="tl tl-y"></span><span className="tl tl-g"></span>
      </div>
      <div className="side-scroll">
        <div className="side-head">资料库</div>
        <div
          className={'side-item' + (view.type === 'library' ? ' is-active' : '')}
          onClick={() => setView({ type: 'library' })}
        >
          <Icon name="note" size={15} style={{ color: 'var(--accent)' }} />
          <span>歌曲</span>
        </div>
        <div className="side-head">播放列表</div>
        {playlists.map((p) => (
          <div
            key={p.id}
            className={'side-item' + (view.type === 'playlist' && view.id === p.id ? ' is-active' : '')}
            onClick={() => setView({ type: 'playlist', id: p.id })}
          >
            <Icon name="playlist" size={15} style={{ color: 'var(--accent)' }} />
            <span>{p.name}</span>
          </div>
        ))}
      </div>
    </aside>
  );
}

// ───────────────────────── 歌曲表格 ─────────────────────────
function SongTable({ songs, albumsById, currentId, isPlaying, selectedId, onSelect, onPlay, onMenu, emptyHint }) {
  if (!songs.length) {
    return <div className="empty-hint">{emptyHint || '没有找到歌曲'}</div>;
  }
  return (
    <div className="table">
      <div className="thead">
        <div className="c-num">#</div>
        <div>标题</div>
        <div>艺术家</div>
        <div>专辑</div>
        <div className="c-time">时长</div>
        <div></div>
      </div>
      {songs.map((s, i) => {
        const album = s.albumId ? albumsById[s.albumId] : null;
        const isCur = s.id === currentId;
        return (
          <div
            key={s.id}
            className={'row' + (isCur ? ' is-current' : '') + (s.id === selectedId ? ' is-selected' : '')}
            onClick={() => onSelect(s.id)}
            onDoubleClick={() => onPlay(s, i)}
            onContextMenu={(e) => { e.preventDefault(); onSelect(s.id); onMenu(s, e.clientX, e.clientY); }}
          >
            <div className="c-num">
              {isCur ? (
                <EqBars paused={!isPlaying} />
              ) : (
                <span className="num-wrap">
                  <span className="num">{i + 1}</span>
                  <button className="num-play" title="播放" onClick={(e) => { e.stopPropagation(); onPlay(s, i); }}>
                    <Icon name="play" size={13} />
                  </button>
                </span>
              )}
            </div>
            <div className="c-title">
              <Cover album={album} size={36} />
              <span className={'t-name' + (isCur ? ' t-accent' : '')}>{s.title}</span>
            </div>
            <div className="c-dim">{s.artist || (album ? album.artist : '未知艺人')}</div>
            <div className="c-dim">{album ? album.title : '未知专辑'}</div>
            <div className="c-time c-dim">{formatTime(s.duration)}</div>
            <div className="c-more">
              <button className="icon-btn" title="更多" onClick={(e) => { e.stopPropagation(); const r = e.currentTarget.getBoundingClientRect(); onMenu(s, r.left, r.bottom + 4); }}>
                <Icon name="more" size={16} />
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ───────────────────────── 右键菜单 ─────────────────────────
function ContextMenu({ menu, playlists, onAction, onClose }) {
  const ref = vUseRef(null);
  const [pos, setPos] = vUseState({ x: menu.x, y: menu.y });
  const [subOpen, setSubOpen] = vUseState(false);
  vUseEffect(() => {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    let { x, y } = menu;
    if (x + r.width > window.innerWidth - 8) x = window.innerWidth - r.width - 8;
    if (y + r.height > window.innerHeight - 8) y = menu.y - r.height;
    setPos({ x, y });
  }, [menu]);
  vUseEffect(() => {
    const close = () => onClose();
    window.addEventListener('mousedown', close);
    window.addEventListener('blur', close);
    return () => { window.removeEventListener('mousedown', close); window.removeEventListener('blur', close); };
  }, [onClose]);
  const item = (label, action, danger) => (
    <div
      className={'menu-item' + (danger ? ' is-danger' : '')}
      onMouseDown={(e) => e.stopPropagation()}
      onMouseEnter={() => setSubOpen(false)}
      onClick={() => { onAction(action); onClose(); }}
    >{label}</div>
  );
  return (
    <div className="menu" ref={ref} style={{ left: pos.x, top: pos.y }} onContextMenu={(e) => e.preventDefault()}>
      {item('立即播放', { type: 'play' })}
      {item('下一首播放', { type: 'playNext' })}
      {item('添加到待播清单', { type: 'addQueue' })}
      <div className="menu-sep"></div>
      <div
        className="menu-item has-sub"
        onMouseDown={(e) => e.stopPropagation()}
        onMouseEnter={() => setSubOpen(true)}
      >
        <span>添加到播放列表</span>
        <Icon name="chevron" size={12} />
        {subOpen && (
          <div className="menu submenu">
            {playlists.map((p) => (
              <div key={p.id} className="menu-item" onClick={() => { onAction({ type: 'addToPlaylist', playlistId: p.id }); onClose(); }}>{p.name}</div>
            ))}
          </div>
        )}
      </div>
      <div className="menu-sep"></div>
      {item('在 Finder 中显示', { type: 'reveal' })}
      {item('从资料库中删除', { type: 'remove' }, true)}
    </div>
  );
}

// ───────────────────────── 待播队列面板 ─────────────────────────
function QueuePanel({ open, current, manual, upcoming, albumsById, isPlaying, onClose, onClear, onPlayManual, onPlayContext, onRemoveManual }) {
  const hasUpcoming = manual.length > 0 || upcoming.length > 0;
  return (
    <div className={'queue-panel' + (open ? ' is-open' : '')} data-screen-label="待播清单">
      <div className="queue-head">
        <span className="queue-title">待播清单</span>
        <div className="queue-head-actions">
          {hasUpcoming && <button className="text-btn" onClick={onClear}>清空</button>}
          <button className="icon-btn" title="关闭" onClick={onClose}><Icon name="x" size={15} /></button>
        </div>
      </div>
      <div className="queue-scroll">
        {current ? (
          <div>
            <div className="queue-sec">正在播放</div>
            <div className="q-row is-current">
              <Cover album={current.albumId ? albumsById[current.albumId] : null} size={34} />
              <div className="q-meta">
                <div className="q-name t-accent">{current.title}</div>
                <div className="q-artist">{current.artist || (current.albumId && albumsById[current.albumId] ? albumsById[current.albumId].artist : '未知艺人')}</div>
              </div>
              <EqBars paused={!isPlaying} />
            </div>
          </div>
        ) : (
          <div className="empty-hint">当前没有播放内容</div>
        )}
        {manual.length > 0 && (
          <div>
            <div className="queue-sec">插播 · 下一首播放</div>
            {manual.map((s, i) => (
              <div key={s.id + '-m' + i} className="q-row" onDoubleClick={() => onPlayManual(i)}>
                <Cover album={s.albumId ? albumsById[s.albumId] : null} size={34} />
                <div className="q-meta">
                  <div className="q-name">{s.title}</div>
                  <div className="q-artist">{s.artist || (s.albumId && albumsById[s.albumId] ? albumsById[s.albumId].artist : '未知艺人')}</div>
                </div>
                <button className="icon-btn q-x" title="从队列移除" onClick={() => onRemoveManual(i)}><Icon name="x" size={13} /></button>
              </div>
            ))}
          </div>
        )}
        {upcoming.length > 0 && (
          <div>
            <div className="queue-sec">接下来</div>
            {upcoming.map((s, i) => (
              <div key={s.id + '-c' + i} className="q-row" onDoubleClick={() => onPlayContext(i)}>
                <Cover album={s.albumId ? albumsById[s.albumId] : null} size={34} />
                <div className="q-meta">
                  <div className="q-name">{s.title}</div>
                  <div className="q-artist">{s.artist || (s.albumId && albumsById[s.albumId] ? albumsById[s.albumId].artist : '未知艺人')}</div>
                </div>
              </div>
            ))}
          </div>
        )}
        {current && !hasUpcoming && <div className="empty-hint small">队列中暂无后续歌曲<br />在歌曲上右键选择「下一首播放」试试</div>}
      </div>
    </div>
  );
}

// ───────────────────────── 底部播放条 ─────────────────────────
function PlayBar({ song, album, isPlaying, progress, volume, shuffle, repeat, queueOpen, onToggle, onPrev, onNext, onSeek, onVolume, onShuffle, onRepeat, onQueue }) {
  return (
    <footer className="playbar" data-screen-label="播放条">
      {album && (
        <div
          className="pb-ambient"
          style={{ background: `linear-gradient(90deg, oklch(0.65 0.1 ${album.h1} / 0.2), transparent 40%, transparent 60%, oklch(0.65 0.1 ${album.h2} / 0.16))` }}
        ></div>
      )}
      <div className="pb-left">
        {song ? (
          <div className="pb-now">
            <Cover album={album} size={48} radius={7} />
            <div className="pb-meta">
              <div className="pb-name">{song.title}</div>
              <div className="pb-artist">{song.artist || (album ? album.artist : '未知艺人')}</div>
            </div>
          </div>
        ) : (
          <div className="pb-now pb-idle">
            <div className="cover cover-idle" style={{ width: 48, height: 48, borderRadius: 7 }}>
              <Icon name="note" size={20} />
            </div>
            <div className="pb-meta"><div className="pb-artist">未在播放</div></div>
          </div>
        )}
      </div>
      <div className="pb-center">
        <div className="pb-controls">
          <button className={'icon-btn pb-mode' + (shuffle ? ' is-on' : '')} title="随机播放" onClick={onShuffle}>
            <Icon name="shuffle" size={17} />
          </button>
          <button className="icon-btn pb-skip" title="上一首" onClick={onPrev} disabled={!song}>
            <Icon name="prev" size={22} />
          </button>
          <button className="pb-play" title={isPlaying ? '暂停' : '播放'} onClick={onToggle} disabled={!song}>
            <Icon name={isPlaying ? 'pause' : 'play'} size={24} />
          </button>
          <button className="icon-btn pb-skip" title="下一首" onClick={onNext} disabled={!song}>
            <Icon name="next" size={22} />
          </button>
          <button className={'icon-btn pb-mode' + (repeat !== 'off' ? ' is-on' : '')} title={repeat === 'off' ? '循环播放:关' : repeat === 'all' ? '列表循环' : '单曲循环'} onClick={onRepeat}>
            <Icon name={repeat === 'one' ? 'repeat1' : 'repeat'} size={17} />
          </button>
        </div>
        <div className="pb-progress">
          <span className="pb-time">{song ? formatTime(progress) : '-:--'}</span>
          <Slider className="pb-slider" value={song ? progress : 0} max={song ? song.duration : 1} onChange={(v) => song && onSeek(v)} />
          <span className="pb-time">{song ? '-' + formatTime(song.duration - progress) : '-:--'}</span>
        </div>
      </div>
      <div className="pb-right">
        <Icon name={volume === 0 ? 'mute' : 'volume'} size={17} style={{ color: 'var(--text-2)' }} />
        <Slider className="vol-slider" value={volume} max={1} onChange={onVolume} />
        <button className={'icon-btn pb-mode' + (queueOpen ? ' is-on' : '')} title="待播清单" onClick={onQueue}>
          <Icon name="queue" size={18} />
        </button>
      </div>
    </footer>
  );
}

Object.assign(window, { Sidebar, SongTable, ContextMenu, QueuePanel, PlayBar });
