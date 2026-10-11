# 战斗界面美术验证

此目录保留第一轮探索；当前效果与验证请看 [第二轮](../battle-ui-v2/README.md)。

日期：2026-10-11。使用 Godot 4.6 / Metal 实际渲染；截图为游戏原生 UI。

## 最终效果

- [建造面板 · 1080p / 中文](gallery-worker.png)
- [建造面板 · 720p / 150%](gallery-worker-720p.png)
- [单位指令](gallery-tank.png)
- [生产面板](gallery-vehiclefactory.png)
- [暂停菜单](gallery-pause.png)
- [科技面板](gallery-technology.png)
- [可视化程序编辑器](gallery-rules.png)
- [英文暂停菜单 · 720p](pause-bastion-en-150.png)
- [科技面板 · 中文 / 720p](technology-helix-zh_CN-150.png)
- [战役结算](interface-result-150-720p.png)
- [生产说明与费用](roster-info-bastion-available.png)
- [建造说明](roster-info-helix-construction.png)

## 改动

内置 image_gen 生成的指挥舱插画与暗色工业材质接入共享 BattleTheme。面板、原生按钮、弹出菜单、输入框、滚动条、程序标签页与悬停说明统一使用石板色、暖铜色和象牙白。主操作使用背景填充强调，保留清晰的键盘焦点。

单位标题加入立绘图标；生产 / 建造卡片改为图标在上、文字在下，避免长名称与费用挤压图标。继续使用原生 Button 的 [icon_alignment / vertical_icon_alignment](https://docs.godotengine.org/en/4.6/classes/class_button.html#class-button-property-vertical-icon-alignment)，保留原有键盘和无障碍语义。

暂停菜单默认聚焦恢复战斗，操作说明可展开。科技滚动区域预留插画标题高度。位图不包含功能文字，中英文仍由游戏本地化系统绘制。

素材与完整提示词见 [美术记录](../../assets/ui/art/battle/README.md)。

## 验证结果

- Godot 资源导入与程序编辑器解析通过。
- 修改涉及的 19 个脚本通过 gdformat / gdlint；git diff --check 通过。
- BattleArtPreview：Bastion / Helix，720p、100% / 125% / 150%，900p / 1080p，以及战役结算，0 failures。覆盖实际地图输入、单位指令、警报、可视化 / Lua 编辑器、存档弹窗和暂停状态。中英文科技、暂停菜单及操作说明展开 / 收起均通过。
- RosterInfoPreview：两个阵营的键盘购买、正确扣费、缺少资源 / 建筑、低电力、建造说明与悬停弹窗，0 failures。
- BattleArtPreview --gallery：Frontier 海港地图、中文 1080p 与 720p / 150% 建造卡片逐个滚动可达，0 failures。
- 人工检查实际渲染截图：材质不压过文字，插画标题具有暗色文字遮罩，卡片图标清晰，面板和科技弹窗未越出窗口。

RosterInfoPreview 结束时仍输出 ObjectDB / 2 resources 清理诊断，未出现脚本异常或交互断言失败；同类退出诊断在已有 [Roster layout 验证记录](../../docs/playtests/2026-10-06/ROSTER_LAYOUT.md) 中也有记录。本次未定位或修改该独立清理问题。

运行命令：

```sh
godot --path . --script tests/rendered/BattleArtPreview.gd
godot --path . --script tests/rendered/BattleArtPreview.gd -- --gallery
godot --path . --script tests/rendered/RosterInfoPreview.gd
```

图库模式为了展示 UI 与场景关系在测试进程中揭示地图；常规对局的战争迷雾逻辑未变。
