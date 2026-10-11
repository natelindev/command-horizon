# 阵营配乐替换

## 阶段

1. 查验旧 Suno 任务和网络曲目的来源、授权与配器；按用户要求排除管弦音乐。
2. 选定菜单与三阵营的成品曲目：工业节奏、冰冷科幻电子、吉他摇滚分开定位；下载原文件并保留来源。
3. 制作适合后台播放的响度与循环版本，替换旧占位曲；加入完整署名、许可与修改说明。
4. 验证解码、峰值、循环和场景切换，运行音乐回归并提供试听入口。

## Agent 进度

- 2026-10-11：旧四个 Suno 任务仍为 submitting，没有音频；不再依赖该接口。
- 用户确认可使用网络免费授权音乐，各阵营不同风格，并明确不要管弦音乐。
- 已取得 Zander Noriega 的 The Recon Mission、Perpetual Tension、Stonemason 原始 WAV，均从作者 OpenGameArt 页面核对 CC BY 3.0；正在筛选菜单和工业行军曲。
- 已完成四首替换：菜单 Nebulous、Bastion Rock of War、Helix Perpetual Tension、Frontier The Recon Mission；完整曲长分别约 236、204、162、183 秒。
- 已固定原文件 SHA-256、下载地址和授权来源；添加导入脚本、Ogg 元数据、随包 LICENSES.md 及游戏内可点击署名。
- 统一约 −20 LUFS；解码真峰值最高 −3.64 dBTP，无削波；循环首尾最大样本差 0.0000654。保留原曲首尾，采用整曲重复，并非按节拍无缝拼接。
- MusicRegression：0 failures；覆盖播放、长度、循环、淡入淡出、快速切换、暂停、静音和音量。GDScript 格式及 lint 通过，git diff --check 通过。
- 中英文署名页顶部和底部均已渲染检查，滚动内容、许可链接与返回按钮可见。试听节选位于 tmp/music/previews；按源页面配器介绍筛选，未声称完成主观听感验证。
- 测试退出仍出现既有 ObjectDB / resources-in-use 清理提示，无脚本异常；本次未扩展处理全局资源清理问题。
- 旧程序合成器改为写入 tmp/music/procedural-legacy，避免覆盖正式配乐。所有阶段完成，未新增付费生成任务。
