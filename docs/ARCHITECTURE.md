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
  ├─ C# Gameplay Core
  │   ├─ PlayerCommand 玩家意图边界
  │   └─ CombatRules 确定性战斗规则
  ├─ Main 场景
  │   ├─ 实时渲染 3D 云津渡背景
  │   ├─ 摄像机射线点击地面
  │   └─ CanvasLayer 网游式 HUD
  ├─ CloudFordWorld3D
  │   ├─ SubViewport 实时 3D 世界
  │   ├─ 斜视角平滑镜头跟随
  │   ├─ 可保存昼夜、薄雾细雨与夜间灯笼
  │   ├─ 建筑遮挡渐隐与战斗镜头震动
  │   ├─ 屏幕坐标与世界坐标转换
  │   ├─ NavigationMesh 建筑绕障区域
  │   └─ CombatVfx3D 技能与移动反馈
  ├─ WuxiaActor3D
  │   ├─ CharacterBody3D 玩家与敌人
  │   ├─ 程序化低多边形有关节角色
  │   ├─ AnimationTree 待机、跑动、攻击、受击与倒地状态
  │   ├─ NavigationAgent3D 路径移动
  │   ├─ 巡逻、警戒、追击和脱战
  │   └─ 名牌、选中环、攻击和受击表现
  └─ GameState
      ├─ 气血、内力、攻击、防御与武学状态
      ├─ 境界经验、区域声望与路线选择
      ├─ 背包、装备、消耗品与掉落
      ├─ 两阶段任务状态机、敌人波次与分支奖励
      ├─ JSON 版本化存档与世界快照
      ├─ 音量和全屏设置持久化
      └─ 离线游戏状态边界

Windows 发布
  ├─ Godot Windows x64 EXE + PCK
  └─ Inno Setup LZMA2 安装包
```

当前保持离线单机，但场景、实体、状态与 UI 已分层，未来可在 `GameState`
之后增加 Nakama 或自建服务端适配层，而不需要重写表现层。

第三方来源与许可详见 `THIRD_PARTY_NOTICES.md`。
