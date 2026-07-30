## Context

Git 历史显示，提交 `b4e4802` 之前仅有浅色/深色两态：`AppState.theme` 是唯一主题状态，`RootView` 直接挂在 `WindowGroup`，工具栏使用普通按钮切换。三态系统主题提交同时引入了模式/实际主题双状态、根包装视图与原生菜单，之后出现卡顿和主题残留。

## Goals / Non-Goals

**Goals:**

- 精确恢复 Git 中已知正常的浅色/深色主题链路。
- 保留浅色/深色选择的持久化和现有视觉令牌。

**Non-Goals:**

- 不重新设计主题配色或组件视觉。
- 不改变播放、曲库或窗口尺寸行为。
- 不保留系统跟随模式。

## Decisions

1. **以 `AppTheme` 作为唯一状态。** `AppState.theme` 直接保存 `.light` 或 `.dark`，变更时持久化到原有 `lmp-theme` 键。
2. **恢复普通按钮切换。** 按钮图标提示目标主题，点击后直接翻转 `app.theme`，沿用引入系统模式前的页面动画。
3. **恢复直接根结构。** `RootView` 直接作为 `WindowGroup` 内容，并由 `app.theme` 设置固定 `preferredColorScheme`。
4. **兼容历史偏好。** `light` 和 `dark` 正常恢复；无法解析的 `system` 按旧逻辑回退为浅色。

## Risks / Trade-offs

- [移除系统跟随能力] → 这是本次明确回退范围；用户仍可随时在浅色和深色之间手动切换。
- [旧的 `system` 持久化值无法解析] → 按已知正常实现回退为浅色，并在下一次手动切换后写入有效值。
