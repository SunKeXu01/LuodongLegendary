# 技术架构：Godot 原生 Windows 武侠游戏

本项目以 `JevLOMCN/mir1`（Unlicense）作为技术迁移来源，固定参考提交为 `2655bb7b1103bf6514506abddcc1925a9bbd74cb`。

## 历史迁移模块

| 上游通用结构                               | 《泺栋传奇》实现                    |
| ------------------------------------------ | ----------------------------------- |
| `Map.cs` 的矩形 Cell、有效点和可行走点缓存 | `WuxiaWorldMap`                     |
| `MapObject.cs` 的地图实体、位置与阻挡语义  | `WorldObject` 与移动校验            |
| 安全区区域标记                             | `SafeZone` 与 `WorldCell.safeZone`  |
| 服务端规则与客户端表现分离                 | `assets/scripts/game` 与 `src` 分层 |

## 没有迁移的内容

未使用上游的 Mir 名称、二进制地图、协议编号、数据库、数值、角色、职业、物品、怪物、图像、声音或其他内容资产。Windows MVP 是完全离线的，因此不移植账号服、游戏服、聊天、公会和交易协议。

上述 TypeScript 模块保留为规则原型与历史参考。v0.4.0 起，正式客户端使用
Godot 4.7.1，不再依赖浏览器或 Electron 运行。

## Godot Windows 单机分层

```text
Godot 4.7.1
  ├─ Main 场景
  │   ├─ 原创 2.5D 云津渡背景
  │   ├─ NavigationRegion2D 可行走区域
  │   └─ CanvasLayer 网游式 HUD
  ├─ WuxiaActor
  │   ├─ NavigationAgent2D 点击寻路
  │   ├─ 玩家与敌人表现
  │   └─ 选敌、追击、伤害与死亡
  └─ GameState
      ├─ 气血、碎银与武学状态
      └─ 离线游戏状态边界

Windows 发布
  ├─ Godot Windows x64 EXE + PCK
  └─ Inno Setup LZMA2 安装包
```

当前保持离线单机，但场景、实体、状态与 UI 已分层，未来可在 `GameState`
之后增加 Nakama 或自建服务端适配层，而不需要重写表现层。

第三方来源与许可详见 `THIRD_PARTY_NOTICES.md`。
