# 泺栋传奇

《泺栋传奇》是一款明中叶架空背景的复古武侠 Windows 单机游戏。当前 `v0.3.0` 已直接迁移开源 RPG 的完整瓦片地图、角色图集和行走动画，并在此基础上加入云津渡探索、敌人追击、实时战斗、伤害反馈、碎银掉落与离线存档。

## Windows 游玩

从 GitHub Releases 下载 `LuodongLegendary-0.3.0-win-x64.exe`，双击即可运行。客户端为 portable 单文件版本，不需要安装，也不需要联网。

游戏内使用 `WASD` 或方向键移动，按空格或 `J` 出招。

## 本地开发

需要 Node.js 22 与 pnpm 10：

```bash
pnpm install
pnpm check
pnpm desktop:dev
```

构建 Windows x64 portable 客户端：

```bash
pnpm desktop:win
```

## 开源技术迁移

地图 Cell 结构迁移自 Unlicense 项目 `JevLOMCN/mir1`；可视化基础直接迁移自 MIT 项目 `remarkablegames/phaser-rpg`，包括 Tiled 地图、瓦片素材、角色图集、行走动画、Arcade Physics 碰撞及镜头结构。固定来源和实际迁移范围见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目没有使用 Mir 系列的名称、地图、数据库、协议编号、角色、物品、怪物或素材。《泺栋传奇》的明朝武侠世界、剧情内容、数值与界面均为原创；当前开源 RPG 示例美术将随开发逐步替换为原创复古武侠素材。

## 文档

- [产品需求](docs/PRD.md)
- [剧情与产品方向](docs/PRODUCT_DIRECTION.md)
- [技术架构](docs/ARCHITECTURE.md)
- [开发说明](docs/DEVELOPMENT.md)
