# 开发说明

## 当前进度

项目当前为《泺栋传奇》Godot Windows 单机原型：

- `godot/scenes/main.tscn`：Godot 正式客户端入口。
- `godot/scripts/main.gd`：鼠标指令、自动追击战斗和网游式 HUD。
- `godot/scripts/isometric_camera_rig_3d.gd`：移植并扩展的正交等距镜头、缩放、跟随与震动。
- `godot/scripts/wuxia_actor_3d.gd`：有关节的低多边形武侠角色、动画状态机、移动与战斗。
- `godot/scripts/cloud_ford_world_3d.gd`：云津渡实时 3D 场景、昼夜细雨、遮挡渐隐、镜头反馈与鼠标射线换算。
- `godot/scripts/silent_temple_world_3d.gd`：寂音禅院独立地图、夜雨、牢房、机关踏板、总闸与导航区域。
- `godot/scripts/game_state.gd`：属性、背包、装备、任务、存档与设置状态。
- `godot/scripts/audio_manager.gd`：UI、战斗、拾取和任务反馈音效。
- `installer/luodong-legendary.iss`：可自选安装目录的压缩安装包定义。
- `WuxiaRaidController` 与 `WuxiaWorldMap`：旧 TypeScript 规则原型。
- `assets/configs/story-content.json`：主线、副本、支线和随机奇遇的独立内容清单。
- `src`：v0.3.0 Phaser 原型，保留作迁移记录，不再作为正式客户端发布。

旧版围猫和动物打宝原型已从首版代码中移除。

当前云津渡序章包含“护送百姓 / 追查证据”两条开局路线。两条路线使用同一
两阶段任务状态机，但分别奖励声望或锻造材料；第一轮暗桩清剿完成后会动态
生成寒岭追兵，最终奖励进阶兵器并触发境界成长。路线、任务阶段、声望、
经验、属性上限和敌人存活状态均写入离线存档。

完成序章后可从沈砚对话进入寂音禅院。副本状态依次为夜探守卫、关闭机关、
营救顾行舟、院主首领战和结局裁定。副本与云津渡共用角色实例和 HUD，
切换时重建世界、NPC 与敌人波次；存档会记录 `current_zone`、副本状态、
结局以及当前区域内仍存活的敌人。

巡夜守卫通过 `WuxiaActor3D.enable_vision_cone()` 获得本地前向扇形和
`can_see()` 朝向判定。没有触发警戒时点击总闸可绕过守卫，并记录
`dungeon_approach = stealth`；主动攻击或进入视野会转入强攻。院主首领战
按 66% 和 33% 气血分为三阶段，地面红色预警结束时才结算伤害，玩家可用
鼠标点击圈外地面躲避。

武学栏采用技能队列模型。选中敌人后青冥剑式自动循环；伏虎掌和机弩术
必须点击按钮排队，角色会按 1.55 / 5.6 丈射程自动接近后施放。踏燕行和
调息为即时自用技能。所有绝技拥有独立冷却和内力消耗，战斗中每息恢复
2 点内力、脱战时每息恢复 4.5 点。伏虎掌命中正在蓄力的院主会额外延长
0.35 息预警时间。

云津渡同时生成可点击的铁匠鲁三火。铁匠界面读取当前兵刃的淬炼等级、
寒铁和碎银数量，按照“下一等级份数的寒铁 + 下一等级 × 25 两碎银”的规则
稳定提升至 `+5`，每级增加 2 点外功攻击。淬炼没有随机失败或装备损坏；
资源不足时不扣除任何物品。强化等级会同步到背包、角色面板与存档。

正式地图使用正交斜俯视相机形成 2.5D 网游观感，但底层仍是完整 3D：
角色使用 `CharacterBody3D`，移动使用 `NavigationAgent3D`，地图、光照、
雨雾、碰撞和技能表现均在 3D 世界中结算。鼠标滚轮调整镜头距离；NPC
任务/功能标识、敌人境界与气血条、掉落光柱会随世界透视缩放。建筑位于
摄像机与玩家之间时会渐隐。

云津渡茶棚是首个通用地图设施交互：鼠标命中只提交意图，玩家先通过导航
接近设施，进入 1.45 丈范围后才执行休整并恢复气血、内力。NPC、敌人、
机关、掉落和茶棚都遵循同一套“命中—寻路—距离校验—结算”结构。

## 本地运行

安装 Godot 4.7.1 .NET 版本和 .NET 8 SDK 后：

```bash
godot --path godot --editor
```

也可以直接启动游戏：

```bash
godot --path godot
```

## Windows 客户端

Godot 命令行导出：

```bash
godot --headless --path godot --export-release "Windows Desktop" \
  build/windows/LuodongLegendary.exe
```

在 Windows 上使用 Inno Setup 6 生成安装包：

```bash
iscc /DMyAppVersion=0.6.0 installer/luodong-legendary.iss
```

安装包允许玩家选择安装位置，并使用 LZMA2 固实压缩。网络功能仍不在
单机 MVP 范围内，但客户端已采用适合继续扩展网游模块的引擎架构。

存档和设置使用 Godot `user://` 数据目录，不会写入游戏安装目录。Windows
上对应当前用户的应用数据目录，因此安装到只读目录时仍可正常保存。
