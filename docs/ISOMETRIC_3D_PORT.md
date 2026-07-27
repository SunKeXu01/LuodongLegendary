# 等距 3D 技术移植记录

## 选型结论

《泺栋传奇》的正式表现层采用 Godot 4.7.1 原生 3D，并使用固定斜俯视、
正交投影构成 2.5D 网游观感。上游选型固定为
[`marinho/isometric-3d-toolkit`](https://github.com/marinho/isometric-3d-toolkit)
提交 `95d3507560f80e44a8eb67f40807185c8d0b10fb`，许可证为 CC BY 4.0。

该上游被选中是因为它针对 Godot 4 的等距/正交 3D，而不是把 2D 像素地图
继续包装成伪 3D。另行审计的 `EeroLai/abyssal-walker` 和
`fragule-hub/Godot4.6-Isometric-SRPG-game-demo` 都是 2D；未提供清晰根
许可证的 3D ARPG 仓库不进入发行代码。

## 已迁移边界

| 上游技术结构 | 《泺栋传奇》落地 |
| --- | --- |
| `IsometricCamera3D` 相机职责分离 | `IsometricCameraRig3D` 独立镜头节点 |
| `CameraShaker` 目标震动与衰减 | 有界、确定性的 3D 战斗镜头震动 |
| 等距/正交相机方向 | 正交 2.5D 投影、固定斜俯视和阻尼跟随 |
| 激活区域与可交互对象分离 | 鼠标命中、自动寻路、交互距离、效果结算四段链 |
| `VisibilitySwitcher` 遮挡职责 | 摄像机到玩家射线穿过建筑时渐隐 |

项目额外实现鼠标滚轮缩放、屏幕射线到地面的点击寻路、NPC/敌人/设施悬停
反馈、世界空间任务标识、敌人境界和气血条。现有任务、战斗、背包、锻造、
副本和 JSON 存档仍由原创 `GameState` 管理，不依赖上游游戏数据。

## 内容与版权边界

只迁移通用引擎技术。没有复制上游地图、美术、音频、角色、剧情或数值。
所有可见内容继续使用《泺栋传奇》的原创明朝武侠命名与场景。

## 可视资产迁移

为了让场景从技术原型进入可游玩的 2.5D 客户端，本项目同时引入两套
KayKit 官方 CC0 资产：

- Medieval Hexagon Pack 1.0：云津渡建筑、铁匠铺、集市、植被与道具；
- Character Pack: Adventures 1.0：玩家、NPC、敌人与首领的骨骼模型和动作。

模型按固定提交筛选并直接由 Godot 导入，没有整包复制未使用的格式。
详细来源与许可证见 `godot/assets/vendor/README.md` 和
`THIRD_PARTY_NOTICES.md`。
