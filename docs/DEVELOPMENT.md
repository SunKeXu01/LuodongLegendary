# 开发说明

## 当前进度

项目当前为《泺栋传奇》Windows 单机原型：

- `WuxiaRaidController`：云津渡剧情选择、确定性招式战斗、碎银和兵器成长。
- `WuxiaWorldMap`：从 Unlicense 参考项目迁移的通用地图 Cell、实体占位和移动规则。
- `assets/configs/story-content.json`：主线、副本、支线和随机奇遇的独立内容清单。
- `src`：不联网的本地试玩页面。
- `tests/game`：脱离任何引擎的规则测试。

旧版围猫和动物打宝原型已从首版代码中移除。

## 本地检查

需要 Node.js 20+ 与 pnpm：

```bash
pnpm install
pnpm check
```

## 试玩原型

```bash
pnpm dev
```

在浏览器打开终端输出的地址（通常为 `http://localhost:5173`）。选择一门武学，在云津渡作出开局决定，再推进三场战斗。当前页面不发起任何网络请求。

## Windows 客户端

桌面客户端使用 Electron 封装，存档保存在 Chromium 的本地用户数据目录。运行：

```bash
pnpm desktop:dev
```

生成 Windows x64 portable 文件：

```bash
pnpm desktop:win
```

网络功能不在单机 MVP 范围内。
