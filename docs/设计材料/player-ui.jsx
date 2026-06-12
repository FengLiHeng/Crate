// 基础 UI 件:图标、封面、均衡器动画、滑杆、Toast
const { useRef: uiUseRef } = React;

const ICON_PATHS = {
  play: <path d="M8 5.3v13.4c0 .8.9 1.3 1.6.9l10.4-6.7c.6-.4.6-1.4 0-1.8L9.6 4.4c-.7-.4-1.6.1-1.6.9z" fill="currentColor" />,
  pause: <g fill="currentColor"><rect x="6.5" y="5" width="3.6" height="14" rx="1.2" /><rect x="13.9" y="5" width="3.6" height="14" rx="1.2" /></g>,
  next: <g fill="currentColor"><path d="M5 6.6v10.8c0 .8.9 1.3 1.6.9l8-5.4c.6-.4.6-1.4 0-1.8l-8-5.4c-.7-.4-1.6.1-1.6.9z" /><rect x="16.5" y="5.5" width="2.6" height="13" rx="1.1" /></g>,
  prev: <g fill="currentColor"><path d="M19 6.6v10.8c0 .8-.9 1.3-1.6.9l-8-5.4c-.6-.4-.6-1.4 0-1.8l8-5.4c.7-.4 1.6.1 1.6.9z" /><rect x="4.9" y="5.5" width="2.6" height="13" rx="1.1" /></g>,
  shuffle: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 7h3.2c4.6 0 6.9 10 11.5 10H20" /><path d="M3 17h3.2c1.6 0 2.9-1.2 4-2.7M20 7h-2.3c-1.7 0-3 1.2-4.1 2.8" /><path d="M17.5 4.5 20 7l-2.5 2.5M17.5 14.5 20 17l-2.5 2.5" /></g>,
  repeat: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M17.5 2.5 20 5l-2.5 2.5" /><path d="M20 5H7.5A4.5 4.5 0 0 0 3 9.5v1" /><path d="M6.5 21.5 4 19l2.5-2.5" /><path d="M4 19h12.5a4.5 4.5 0 0 0 4.5-4.5v-1" /></g>,
  repeat1: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M17.5 2.5 20 5l-2.5 2.5" /><path d="M20 5H7.5A4.5 4.5 0 0 0 3 9.5v1" /><path d="M6.5 21.5 4 19l2.5-2.5" /><path d="M4 19h12.5a4.5 4.5 0 0 0 4.5-4.5v-1" /><path d="M10.9 9.8 12.7 8.5v7" /></g>,
  volume: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M4 9.5v5h3l4.5 3.8V5.7L7 9.5H4z" fill="currentColor" stroke="none" /><path d="M15 9.2a4.2 4.2 0 0 1 0 5.6" /><path d="M17.6 6.8a8 8 0 0 1 0 10.4" /></g>,
  mute: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M4 9.5v5h3l4.5 3.8V5.7L7 9.5H4z" fill="currentColor" stroke="none" /><path d="M15.5 9.5l5 5M20.5 9.5l-5 5" /></g>,
  queue: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M4 6.5h16M4 12h16M4 17.5h9" /></g>,
  note: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9.5 17.5V6.2l10-1.9v11.2" /><circle cx="7" cy="17.5" r="2.5" fill="currentColor" stroke="none" /><circle cx="17" cy="15.5" r="2.5" fill="currentColor" stroke="none" /></g>,
  playlist: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M4 6h16M4 11h16M4 16h7" /><circle cx="16.5" cy="17.5" r="2.2" fill="currentColor" stroke="none" /><path d="M18.7 17.5v-5l2.3-.6" /></g>,
  search: <g fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="10.5" cy="10.5" r="5.8" /><path d="m15 15 4.5 4.5" /></g>,
  plus: <g fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></g>,
  folder: <g fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"><path d="M3 7.2c0-1.1.9-2 2-2h4l2 2.2h8c1.1 0 2 .9 2 2v7.4c0 1.1-.9 2-2 2H5c-1.1 0-2-.9-2-2V7.2z" /></g>,
  sun: <g fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><circle cx="12" cy="12" r="4" /><path d="M12 2.8v2M12 19.2v2M2.8 12h2M19.2 12h2M5.5 5.5l1.4 1.4M17.1 17.1l1.4 1.4M18.5 5.5l-1.4 1.4M6.9 17.1l-1.4 1.4" /></g>,
  moon: <path d="M20.5 14.2A8.5 8.5 0 1 1 9.8 3.5a7 7 0 0 0 10.7 10.7z" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />,
  x: <g fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round"><path d="M6 6l12 12M18 6 6 18" /></g>,
  more: <g fill="currentColor"><circle cx="5.5" cy="12" r="1.7" /><circle cx="12" cy="12" r="1.7" /><circle cx="18.5" cy="12" r="1.7" /></g>,
  chevron: <path d="m9 5.5 6.5 6.5L9 18.5" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />,
};

function Icon({ name, size = 18, style = {} }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={style} aria-hidden="true">
      {ICON_PATHS[name]}
    </svg>
  );
}

// 专辑封面:渐变占位 + 音符
function Cover({ album, size = 36, radius = 6 }) {
  const bg = album
    ? `linear-gradient(145deg, oklch(0.7 0.14 ${album.h1}), oklch(0.4 0.13 ${album.h2}))`
    : 'linear-gradient(145deg, oklch(0.55 0.006 80), oklch(0.36 0.006 80))';
  return (
    <div className="cover" style={{ width: size, height: size, borderRadius: radius, background: bg }}>
      <Icon name="note" size={Math.round(size * 0.46)} style={{ color: 'rgba(255,255,255,0.45)' }} />
    </div>
  );
}

// 歌单封面:最多 4 格马赛克
function PlaylistCover({ playlist, albumsById, songsById, size = 36, radius = 6 }) {
  const albs = [];
  for (const sid of playlist.songIds) {
    const s = songsById[sid];
    const a = s && s.albumId ? albumsById[s.albumId] : null;
    if (a && !albs.find((x) => x.id === a.id)) albs.push(a);
    if (albs.length === 4) break;
  }
  if (albs.length < 4) {
    return <Cover album={albs[0] || null} size={size} radius={radius} />;
  }
  return (
    <div className="cover cover-mosaic" style={{ width: size, height: size, borderRadius: radius }}>
      {albs.map((a) => (
        <div key={a.id} style={{ background: `linear-gradient(145deg, oklch(0.7 0.14 ${a.h1}), oklch(0.4 0.13 ${a.h2}))` }}></div>
      ))}
    </div>
  );
}

// 正在播放的跳动条
function EqBars({ paused = false }) {
  return (
    <div className={'eq' + (paused ? ' eq-paused' : '')}>
      <span></span><span></span><span></span>
    </div>
  );
}

// 通用滑杆(进度/音量)
function Slider({ value, max = 1, onChange, className = '' }) {
  const ref = uiUseRef(null);
  const pct = max > 0 ? Math.min(Math.max(value / max, 0), 1) * 100 : 0;
  const seek = (e) => {
    const r = ref.current.getBoundingClientRect();
    const v = Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1) * max;
    onChange(v);
  };
  const onDown = (e) => {
    e.preventDefault();
    seek(e);
    const mv = (ev) => seek(ev);
    const up = () => {
      window.removeEventListener('mousemove', mv);
      window.removeEventListener('mouseup', up);
    };
    window.addEventListener('mousemove', mv);
    window.addEventListener('mouseup', up);
  };
  return (
    <div className={'slider ' + className} ref={ref} onMouseDown={onDown}>
      <div className="slider-track">
        <div className="slider-fill" style={{ width: pct + '%' }}></div>
      </div>
      <div className="slider-thumb" style={{ left: pct + '%' }}></div>
    </div>
  );
}

function formatTime(sec) {
  if (sec == null || isNaN(sec)) return '-:--';
  sec = Math.max(0, Math.round(sec));
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m + ':' + String(s).padStart(2, '0');
}

function formatTotal(seconds) {
  const min = Math.round(seconds / 60);
  if (min < 60) return min + ' 分钟';
  return Math.floor(min / 60) + ' 小时 ' + (min % 60) + ' 分钟';
}

Object.assign(window, { Icon, Cover, PlaylistCover, EqBars, Slider, formatTime, formatTotal, ICON_PATHS });
