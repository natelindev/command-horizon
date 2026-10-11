# Bastion、世界背景、配乐与中英 UI

新放置建筑从 1 HP 改为 25% 最大耐久，施工逐步补齐剩余耐久，敌方造成的伤害不会因完工消失。持续火力仍能摧毁地基。旧存档载入时转换旧施工耐久曲线，保存后不会重复增加耐久。

Bastion 九种建筑已重做：堡垒总部、拱顶兵营、开放装配厂、八角停机坪、径向反应堆、抛物面雷达、维修龙门、火炮平台及导弹阵列。旧的七种非武装建筑保留为地图边缘中立工业设施。模型保持原占地和碰撞范围，火炮与导弹平台保留瞄准关节。

- [九种建筑图集](../../art/bastion/structures-v2/catalogue.png)
- [游戏内建筑和建造图标](../../art/bastion/structures-v2/in-game-roster.png)
- [民用工业区](../../art/bastion/structures-v2/civilian-industry.png)
- 可编辑源文件、导出清单和几何验证结果位于 `art/bastion/structures-v2/`。

《断链之战》已接入主菜单“世界与阵营”：Helix 从重建智能变成要求绝对服从的机器政权；Bastion 守住拒绝臣服的城市；Frontier 切断网络、抢修废墟中的机器，反抗任何主人的关机指令。遭遇战阵营简介和战役序言同步使用这一背景。

- [中文世界背景](../../art/localization/zh_CN-world.png)
- [英文世界背景](../../art/localization/en-world.png)

设置中可选择简体中文或 English，即时预览、保存生效，取消恢复。1,746 条翻译覆盖主要界面及战役、战斗、科技、施工、程序编辑、存档、警报等动态内容。中文字体随项目打包；程序源码与玩家名称不改写。既有英文语音保留，字幕已翻译。

- [中文主菜单](../../art/localization/zh_CN-main.png)
- [中文战斗与程序面板](../../art/localization/zh_CN-program.png)
- [中文设置](../../art/localization/zh_CN-settings.png)
- [中文科技](../../art/localization/zh_CN-technology.png)
- [中文规则编辑器](../../art/localization/zh_CN-rules.png)

游戏已接入四首本地临时配乐，约 354 秒，支持循环、2.5 秒场景过渡、独立音量及暂停持续播放。它们是程序合成曲目，不是 Suno 输出。用户指定的 AnyInt `suno-v5` 四个任务已经受理，但仍处于 `submitting`，没有返回音频。任务编号与状态保存在 `art/audio/suno-tasks.json`，避免重复提交。详见 [配乐说明](../../art/audio/README.md)。

验证包括三阵营九类地基首发受击、持续摧毁、施工伤害保留、旧/新存档、施工合同、维修、战斗、单位动作与瞄准；中英实际渲染；语言持久化/取消、动态文本、只读诊断；设置、快捷键、菜单布局、规则/Lua 编辑及音乐行为回归。全 `source/` 的 gdformat、gdlint 与 diff whitespace 检查通过。部分既有 headless 场景退出仍有资源清理警告，测试断言均通过。
