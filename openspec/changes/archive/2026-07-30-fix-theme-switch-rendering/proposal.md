## Why

“系统、浅色、深色”三态主题引入后出现明显卡顿和新旧主题残留。为恢复已知稳定的主题体验，本次回退到此前正常工作的浅色/深色两态实现。

## What Changes

- 移除“系统”主题模式和三态菜单。
- 恢复单一 `AppTheme` 状态与普通主题按钮，点击后在浅色和深色之间切换。
- 恢复主题选择持久化；历史 `light`、`dark` 值继续有效，历史 `system` 值回退为默认浅色。
- 恢复引入系统主题前的根视图结构和颜色方案设置。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `app-shell`：主题切换需要及时完成，且切换期间和完成后不得出现旧主题表面残留。

## Impact

- 影响 `src/AppState.swift`、`src/Theme.swift`、`src/CrateApp.swift` 和 `src/Views/LibraryContentView.swift`。
- 删除三态主题专用测试，并恢复截图模式对单一主题状态的验证。
