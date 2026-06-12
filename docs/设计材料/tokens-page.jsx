// Design Tokens 页面内容
const { useState: tpUseState } = React;

// ── token 数据(与 tokens.css 保持一致)──
const COLOR_TOKENS = {
  light: [
    ['--win-bg', 'oklch(0.99 0.002 80)', '窗口背景'],
    ['--sidebar-bg', 'oklch(0.966 0.004 80)', '侧边栏背景'],
    ['--panel-bg', 'oklch(0.975 0.003 80)', '面板背景'],
    ['--playbar-bg', 'oklch(0.978 0.003 80)', '播放条背景'],
    ['--text', 'oklch(0.21 0.005 80)', '主文本', 'text'],
    ['--text-2', 'oklch(0.47 0.008 80)', '次要文本', 'text'],
    ['--text-3', 'oklch(0.62 0.008 80)', '弱文本', 'text'],
    ['--sep', 'oklch(0.25 0.01 80 / 0.1)', '分隔线'],
    ['--hover', 'oklch(0.3 0.01 80 / 0.05)', '悬停态'],
    ['--selected', 'oklch(0.3 0.02 80 / 0.09)', '选中态'],
    ['--ctrl', 'oklch(0.3 0.01 80 / 0.06)', '控件底色'],
    ['--accent', 'oklch(0.6 0.19 30)', '强调色 · 珊瑚红'],
    ['--accent-fg', '#fff', '强调色前景', 'onaccent'],
    ['--accent-soft', 'oklch(0.6 0.19 30 / 0.11)', '强调底色'],
  ],
  dark: [
    ['--win-bg', 'oklch(0.215 0.005 270)', '窗口背景'],
    ['--sidebar-bg', 'oklch(0.25 0.006 270)', '侧边栏背景'],
    ['--panel-bg', 'oklch(0.24 0.006 270)', '面板背景'],
    ['--playbar-bg', 'oklch(0.235 0.006 270)', '播放条背景'],
    ['--text', 'oklch(0.94 0.003 80)', '主文本', 'text'],
    ['--text-2', 'oklch(0.72 0.005 80)', '次要文本', 'text'],
    ['--text-3', 'oklch(0.56 0.005 80)', '弱文本', 'text'],
    ['--sep', 'oklch(0.95 0.01 80 / 0.09)', '分隔线'],
    ['--hover', 'oklch(0.9 0.01 80 / 0.06)', '悬停态'],
    ['--selected', 'oklch(0.9 0.01 80 / 0.1)', '选中态'],
    ['--ctrl', 'oklch(0.9 0.01 80 / 0.08)', '控件底色'],
    ['--accent', 'oklch(0.67 0.18 30)', '强调色 · 珊瑚红'],
    ['--accent-fg', '#fff', '强调色前景', 'onaccent'],
    ['--accent-soft', 'oklch(0.67 0.18 30 / 0.16)', '强调底色'],
  ],
};

const TYPE_SCALE = [
  [24, 700, '视图标题', '.head-title', '歌曲 · My Library'],
  [15, 700, '面板标题', '.queue-title', '待播清单 Up Next'],
  [13.5, 500, '列表主文本', '.row .t-name', '凌晨三点的出租车 Midnight Ferry'],
  [13, 400, '正文 / 菜单 / 按钮', '.menu-item / .btn', '下一首播放 · 添加到待播清单'],
  [12.5, 400, '次要信息', '.head-sub / .c-dim', '25 首歌曲 · 1 小时 41 分钟'],
  [11.5, 600, '表头', '.thead', '标题 / 艺术家 / 专辑 / 时长'],
  [11, 700, '分组标签', '.side-head / .queue-sec', '资料库 · 播放列表 · 插播'],
];

const RADII = [
  [12, '窗口', '.window'],
  [9, '列表行', '.row'],
  [8, '按钮 / 搜索框', '.btn / .search-field'],
  [7, '封面 / 侧栏项', '.cover / .side-item'],
  [6, '菜单项', '.menu-item'],
  [999, '胶囊 / 播放键', '.toast / .pb-play'],
];

const SPACING = [4, 6, 8, 10, 12, 16, 20, 24];

const ICON_LABELS = {
  play: '播放', pause: '暂停', next: '下一首', prev: '上一首',
  shuffle: '随机播放', repeat: '列表循环', repeat1: '单曲循环',
  volume: '音量', mute: '静音', queue: '待播清单', note: '音符',
  playlist: '播放列表', search: '搜索', plus: '导入', folder: '文件夹',
  sun: '浅色模式', moon: '深色模式', x: '关闭', more: '更多', chevron: '展开',
};

function Swatch({ token }) {
  const [v, val, label, kind] = token;
  let chipStyle = { background: `var(${v})` };
  if (kind === 'text') chipStyle = { background: 'var(--win-bg)', color: `var(${v})` };
  if (kind === 'onaccent') chipStyle = { background: 'var(--accent)', color: `var(${v})` };
  return (
    <div className="sw">
      <div className="sw-chip" style={chipStyle}>{kind === 'text' || kind === 'onaccent' ? 'Aa' : ''}</div>
      <div className="sw-meta">
        <div className="sw-name">{label} <code>{v}</code></div>
        <code className="sw-val">{val}</code>
      </div>
    </div>
  );
}

function ThemePanel({ theme, children, label }) {
  return (
    <div className="tpanel" data-theme={theme}>
      <div className="tpanel-label">{label}</div>
      {children}
    </div>
  );
}

function ComponentDemo({ theme }) {
  const [val, setVal] = tpUseState(0.42);
  const [vol, setVol] = tpUseState(0.7);
  const album = window.MUSIC_DATA.albums[1];
  return (
    <div>
      <div className="demo-label">按钮</div>
      <div className="demo-row">
        <button className="btn btn-primary"><Icon name="play" size={14} /><span>播放</span></button>
        <button className="btn"><Icon name="shuffle" size={14} /><span>随机播放</span></button>
        <button className="btn" disabled><Icon name="play" size={14} /><span>禁用</span></button>
        <button className="icon-btn tool-btn"><Icon name="plus" size={17} /></button>
      </div>
      <div className="demo-label">播放控制</div>
      <div className="demo-row">
        <button className="icon-btn pb-mode"><Icon name="shuffle" size={17} /></button>
        <button className="icon-btn pb-skip"><Icon name="prev" size={22} /></button>
        <button className="pb-play"><Icon name="play" size={24} /></button>
        <button className="icon-btn pb-skip"><Icon name="next" size={22} /></button>
        <button className="icon-btn pb-mode is-on"><Icon name="repeat" size={17} /></button>
        <button className="icon-btn pb-mode is-on"><Icon name="repeat1" size={17} /></button>
      </div>
      <div className="demo-label">滑杆(进度 / 音量)</div>
      <div className="demo-row">
        <div className="demo-slider"><Slider value={val} max={1} onChange={setVal} /></div>
        <div className="demo-slider" style={{ width: 110 }}><Slider value={vol} max={1} onChange={setVol} /></div>
      </div>
      <div className="demo-label">封面 / 正在播放</div>
      <div className="demo-row">
        <Cover album={album} size={48} radius={7} />
        <Cover album={window.MUSIC_DATA.albums[4]} size={48} radius={7} />
        <Cover album={null} size={48} radius={7} />
        <EqBars />
        <span style={{ fontSize: 13, color: 'var(--accent)', fontWeight: 500 }}>正在播放</span>
      </div>
      <div className="demo-label">菜单</div>
      <div className="demo-row">
        <div className="menu" style={{ position: 'static', display: 'inline-block' }}>
          <div className="menu-item">立即播放</div>
          <div className="menu-item">下一首播放</div>
          <div className="menu-item">添加到待播清单</div>
          <div className="menu-sep"></div>
          <div className="menu-item is-danger">从资料库中删除</div>
        </div>
      </div>
    </div>
  );
}

function TokensPage() {
  return (
    <div className="wrap">
      <header className="page-head">
        <div className="page-kicker">DESIGN TOKENS</div>
        <h1 className="page-title">本地音乐播放器 · 设计令牌</h1>
        <p className="page-sub">
          单一真源:所有令牌定义在 <code>tokens.css</code>,组件样式在 <code>player.css</code>,本页直接引用同一份文件,与产品永远同步。
          <br /><a href="本地音乐播放器.html">→ 打开播放器</a>
        </p>
      </header>

      <section className="tok-section">
        <h2 className="sec-title">色彩 Colors</h2>
        <p className="sec-sub">60/30/10:干净的中性基底为主,封面内容供色;单一珊瑚红(30°)只用在激活态——播放键、主按钮、进度条、选中态,不使用多色渐变。</p>
        <div className="theme-grid">
          <ThemePanel theme="light" label="浅色 LIGHT">
            {COLOR_TOKENS.light.map((t) => <Swatch key={t[0]} token={t} />)}
          </ThemePanel>
          <ThemePanel theme="dark" label="深色 DARK">
            {COLOR_TOKENS.dark.map((t) => <Swatch key={t[0]} token={t} />)}
          </ThemePanel>
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">专辑封面色板 Album Palette</h2>
        <p className="sec-sub">封面占位渐变:oklch(0.7 0.14 h1) → oklch(0.4 0.13 h2),鲜活饱和 + 玻璃高光——界面的「活力」由内容提供;播放条从当前专辑的 h1 / h2 泛出环境色。</p>
        <div className="card">
          <div className="album-grid">
            {window.MUSIC_DATA.albums.map((a) => (
              <div key={a.id} className="album-card">
                <div className="album-chip" style={{ background: `linear-gradient(145deg, oklch(0.7 0.14 ${a.h1}), oklch(0.4 0.13 ${a.h2}))` }}></div>
                <div>
                  <div className="tok-item-name">{a.title} · {a.artist}</div>
                  <div className="tok-item-val mono">h1 {a.h1}° / h2 {a.h2}°</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">字体 Typography</h2>
        <p className="sec-sub">系统字体栈:-apple-system / SF Pro Text / PingFang SC。数字一律 tabular-nums。</p>
        <div className="card">
          {TYPE_SCALE.map(([size, weight, name, cls, sample]) => (
            <div className="type-row" key={cls}>
              <div className="type-spec"><b>{name}</b>{size}px · {weight} <code>{cls}</code></div>
              <div className="type-sample" style={{ fontSize: size, fontWeight: weight }}>{sample}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">圆角 Radii</h2>
        <div className="card">
          <div className="radii-grid">
            {RADII.map(([r, name, cls]) => (
              <div key={cls}>
                <div className="radius-demo" style={{ borderRadius: r }}></div>
                <div className="tok-item-name">{name}</div>
                <div className="tok-item-val mono">{r === 999 ? '999px' : r + 'px'} · {cls}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">间距 Spacing</h2>
        <p className="sec-sub">基于 2px 网格,常用档位如下(列表行高 52px,播放条高 84px,侧边栏宽 224px)。</p>
        <div className="card">
          <div className="space-grid">
            {SPACING.map((s) => (
              <div key={s}>
                <div className="space-bar" style={{ width: s * 4 }}></div>
                <div className="tok-item-name mono">{s}px</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">图标 Icons</h2>
        <p className="sec-sub">24×24 视区,描边 1.8px、圆头;「列表循环 / 单曲循环」为两枚独立图标(高亮框)。</p>
        <div className="card">
          <div className="icon-grid">
            {Object.keys(ICON_PATHS).map((name) => (
              <div key={name} className={'icon-cell' + (name === 'repeat' || name === 'repeat1' ? ' is-new' : '')}>
                <Icon name={name} size={22} />
                <div className="icon-name">{ICON_LABELS[name] || name}<code>{name}</code></div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tok-section">
        <h2 className="sec-title">组件 Components</h2>
        <p className="sec-sub">与播放器共用 player.css,可直接交互。</p>
        <div className="theme-grid">
          <ThemePanel theme="light" label="浅色 LIGHT">
            <ComponentDemo theme="light" />
          </ThemePanel>
          <ThemePanel theme="dark" label="深色 DARK">
            <ComponentDemo theme="dark" />
          </ThemePanel>
        </div>
      </section>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<TokensPage />);
