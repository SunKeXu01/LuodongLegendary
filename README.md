# 泺栋传奇

《泺栋传奇》是一款明中叶架空背景的 Windows 单机武侠 ARPG。当前 `main`
开发版采用 Godot 4.7.1 .NET，已经具备实时 3D 云津渡、纯鼠标寻路、敌人 AI、
武学战斗、NPC 任务、掉落拾取、背包装备、存档和网游式 HUD。

## Windows 游玩

从 GitHub Releases 下载 `LuodongLegendary-0.4.2-win-x64-setup.exe`。安装向导采用 LZMA2 压缩，玩家可以修改安装目录，也可以选择是否创建桌面快捷方式。游戏仍然不需要联网。

游戏采用纯鼠标操作：点击地面移动，点击敌人后自动接近并攻击，点击 NPC
交谈，点击掉落物自动前往拾取，底部武学和右下角功能入口均可直接点击。

## 本地开发

主客户端需要 Godot 4.7.1 .NET 版本和 .NET 8 SDK：

```bash
godot --path godot --editor
```

导出 Windows x64 客户端：

```bash
godot --headless --path godot --export-release "Windows Desktop" \
  build/windows/LuodongLegendary.exe
```

Windows 安装包通过 `installer/luodong-legendary.iss` 使用 Inno Setup 6 生成。

## 开源技术迁移

当前 Godot 客户端的 3D 云津渡场景、UI、角色、鼠标操作和战斗逻辑均为原创。
旧 Phaser 原型曾迁移 `remarkablegames/phaser-rpg` 的 MIT 示例素材，固定来源和许可见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目没有使用 Mir 系列的名称、地图、数据库、协议编号、角色、物品、怪物或素材。
《泺栋传奇》的明朝武侠世界、剧情内容、数值、3D 场景与界面均为原创。

## 文档

- [产品需求](docs/PRD.md)
- [剧情与产品方向](docs/PRODUCT_DIRECTION.md)
- [技术架构](docs/ARCHITECTURE.md)
- [开发说明](docs/DEVELOPMENT.md)
