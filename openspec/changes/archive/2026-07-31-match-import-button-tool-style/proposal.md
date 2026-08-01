## Why

内容区头部的 `+` 仍使用红色图标和红色悬停背景，而相邻工具按钮使用中性灰色，造成同一工具组内视觉语言不统一。

## What Changes

- `+` 按钮改用与其他头部工具按钮一致的中性图标颜色。
- `+` 按钮悬停时使用与其他头部工具按钮一致的灰色圆角背景。
- 保持按钮尺寸、位置、图标、提示、点击行为和按压反馈不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `interface-motion`：导入按钮不再使用强调色，视觉状态与同组工具按钮保持一致。

## Impact

- `src/Views/LibraryContentView.swift`
- `openspec/specs/interface-motion/spec.md`
