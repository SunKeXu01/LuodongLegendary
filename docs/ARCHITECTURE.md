# 技术架构：从开源桌面 MMORPG 到 Windows 单机游戏

本项目以 `JevLOMCN/mir1`（Unlicense）作为技术迁移来源，固定参考提交为 `2655bb7b1103bf6514506abddcc1925a9bbd74cb`。

## 已迁移模块

| 上游通用结构                               | 《泺栋传奇》实现                    |
| ------------------------------------------ | ----------------------------------- |
| `Map.cs` 的矩形 Cell、有效点和可行走点缓存 | `WuxiaWorldMap`                     |
| `MapObject.cs` 的地图实体、位置与阻挡语义  | `WorldObject` 与移动校验            |
| 安全区区域标记                             | `SafeZone` 与 `WorldCell.safeZone`  |
| 服务端规则与客户端表现分离                 | `assets/scripts/game` 与 `src` 分层 |

## 没有迁移的内容

未使用上游的 Mir 名称、二进制地图、协议编号、数据库、数值、角色、职业、物品、怪物、图像、声音或其他内容资产。Windows MVP 是完全离线的，因此不移植账号服、游戏服、聊天、公会和交易协议。

## Windows 单机分层

```text
Electron 主进程
  ├─ Windows 窗口、生命周期、本地存档路径
  └─ 载入 Vite 构建产物
Renderer
  ├─ 复古武侠 UI
  └─ 输入与状态显示
纯 TypeScript 规则
  ├─ WuxiaWorldMap
  ├─ WuxiaRaidController
  └─ OfflineSave
```

第三方来源与许可详见 `THIRD_PARTY_NOTICES.md`。
