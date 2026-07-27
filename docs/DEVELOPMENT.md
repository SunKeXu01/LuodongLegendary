# 开发说明

## 当前进度

项目当前为《泺栋传奇》Godot Windows 单机原型：

- `godot/scenes/main.tscn`：Godot 正式客户端入口。
- `godot/scripts/main.gd`：鼠标指令、自动追击战斗和网游式 HUD。
- `godot/scripts/wuxia_actor_3d.gd`：玩家和敌人的 3D 实体、移动、碰撞与战斗表现。
- `godot/scripts/cloud_ford_world_3d.gd`：云津渡实时 3D 场景、镜头跟随与鼠标射线换算。
- `godot/scripts/game_state.gd`：属性、背包、装备、任务、存档与设置状态。
- `godot/scripts/audio_manager.gd`：UI、战斗、拾取和任务反馈音效。
- `installer/luodong-legendary.iss`：可自选安装目录的压缩安装包定义。
- `WuxiaRaidController` 与 `WuxiaWorldMap`：旧 TypeScript 规则原型。
- `assets/configs/story-content.json`：主线、副本、支线和随机奇遇的独立内容清单。
- `src`：v0.3.0 Phaser 原型，保留作迁移记录，不再作为正式客户端发布。

旧版围猫和动物打宝原型已从首版代码中移除。

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
iscc /DMyAppVersion=0.4.2 installer/luodong-legendary.iss
```

安装包允许玩家选择安装位置，并使用 LZMA2 固实压缩。网络功能仍不在
单机 MVP 范围内，但客户端已采用适合继续扩展网游模块的引擎架构。

存档和设置使用 Godot `user://` 数据目录，不会写入游戏安装目录。Windows
上对应当前用户的应用数据目录，因此安装到只读目录时仍可正常保存。
