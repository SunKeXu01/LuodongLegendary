# 泺栋传奇

《泺栋传奇》是一款明中叶架空背景的复古武侠 Windows 单机游戏。当前 `v0.1.0` 是首个可玩垂直切片，包含云津渡开局抉择、三门武学、连续战斗、兵器掉落与离线存档。

## Windows 游玩

从 GitHub Releases 下载 `LuodongLegendary-0.1.0-win-x64.exe`，双击即可运行。首版为 portable 单文件版本，不需要安装，也不需要联网。

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

地图 Cell、可行走点缓存、安全区、阻挡实体和移动校验结构迁移自 Unlicense 项目 `JevLOMCN/mir1` 的通用技术设计。固定来源、实际迁移范围与未采用内容见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目没有使用 Mir 系列的名称、地图、数据库、协议编号、角色、物品、怪物或素材。《泺栋传奇》的明朝武侠世界、剧情内容、数值与界面均为原创。

## 文档

- [产品需求](docs/PRD.md)
- [剧情与产品方向](docs/PRODUCT_DIRECTION.md)
- [技术架构](docs/ARCHITECTURE.md)
- [开发说明](docs/DEVELOPMENT.md)
