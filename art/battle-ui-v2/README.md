# 战斗 UI · 第二轮

2026-10-11，Godot 4.6 / Metal 实机渲染截图。

## 视觉方向

按照用户提供的首页参考使用炭灰底、金色细边与象牙白文字。移除第一轮噪点纹理及重复横幅；警报改为开放式时间线，单位卡片去掉实心背景，标签页使用金色下划线，单位肖像直接展示。暂停菜单采用 imagegen 生成的独立海港堡垒插画与宽松的文字菜单。

指令、编队、程序分为原生标签页。相同选区刷新保留当前页；程序问题入口会直接打开程序页。720p 作战计划压缩说明（标题悬停可读），必要时滚动，避免遮住小地图。原生按钮、键盘焦点、翻译与辅助功能语义保留。

## 效果

- [战斗警报](gallery-alerts.png) / [英文 720p](gallery-alerts-en-720p.png)
- [暂停菜单](gallery-pause.png) / [英文 720p](gallery-pause-en-720p.png)
- [建造界面](gallery-worker.png) / [720p](gallery-worker-720p.png)
- [单位指令](gallery-tank.png)
- [生产界面](gallery-vehiclefactory.png)
- [科技](gallery-technology.png)
- [程序编辑器](gallery-rules.png)
- [生产悬停说明](roster-info-bastion-available.png)

当前素材：[frontier-pause-v2.png](../../assets/ui/art/battle/frontier-pause-v2.png)。完整生成提示词与早期探索见 [素材记录](../../assets/ui/art/battle/README.md)。

## 验证

- BattleArtPreview：Bastion / Helix，100% / 125% / 150%，720p、900p、1080p；中英文暂停与科技、地图命令、警报、编辑器、存档、战役结算，0 failures。
- 最终 BattleArtPreview --gallery：Frontier 海港地图、1080p / 720p；中文与英文暂停标题完整，操作说明可展开，建造卡片滚动可达，作战计划不遮挡小地图，0 failures。
- 标签页真实鼠标、键盘切换；刷新保留页签且不改变选区，0 failures。
- BattleAlertsPreview：两个阵营与战役；打开、已读、导航、清理、Escape 与暂停隔离，0 failures。
- RosterInfoPreview：修复新版工具提示的双层边框与窗口溢出后，两阵营全部购买、退款、费用、禁用状态与悬停场景，0 failures。
- ProgramIssuesPreview：三阵营的问题发现、程序页定位、地图重新指定与恢复，0 failures。
- ProgramIssuesEdges（`--headless --max-fps 60`）：异步选区竞态与模态隔离，0 failures。该脚本按渲染帧等待，未限帧的首次运行没有等到守卫阻塞状态；按 60 FPS 运行后通过。
- BattlePlanPreview：主操作、生产入口、键盘收起 / 展开、与小地图的分隔，最终两轮均为 0 failures。早期运行出现过偶发的鼠标激活遗漏；增加按钮事件断言和失败诊断后未重现，尚未确定该偶发现象的原因。
- 修改的 20 个脚本通过 gdlint / gdformat；`git diff --check` 通过。

部分渲染和退出流程仍输出 ObjectDB、资源或粒子着色器清理诊断；未将这些诊断描述为已修复。没有出现运行期脚本异常。第一轮也记录了同类退出问题。

图库模式只在测试进程中揭示地图并固定镜头，截图是实际原生 UI，不是生成的界面合成图。

程序编辑器、程序问题与作战计划已于 2026-10-20 随相关功能一并移除；上方对应验证条目仅作历史记录，以下命令仅列出仍存在的预览。

```sh
godot --path . --script tests/rendered/BattleArtPreview.gd
godot --path . --script tests/rendered/BattleArtPreview.gd -- --gallery
godot --path . --script tests/rendered/BattleAlertsPreview.gd
godot --path . --script tests/rendered/RosterInfoPreview.gd
```
