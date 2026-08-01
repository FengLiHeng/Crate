## Why

内容区头部的 `+` 在常态下持续显示浅红色圆角背景，与相邻工具按钮的轻量样式不一致，也让一次性文件导入显得被过度强调。

## What Changes

- 移除 `+` 按钮常态下的浅红色圆角背景。
- 保留红色 `+` 图标，并只在鼠标悬停时显示浅红色圆角反馈。
- 保持按钮尺寸、位置、点击行为与按压缩放反馈不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `interface-motion`：明确内容区导入按钮的常态与悬停视觉反馈。

## Impact

- `src/Views/LibraryContentView.swift`
- `openspec/specs/interface-motion/spec.md`
