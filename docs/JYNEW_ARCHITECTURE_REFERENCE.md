# JYNew 架构借鉴与原创重写边界

## 结论

`jynew/jynew` 是完成度很高的 Unity 武侠 RPG 学习工程，但其项目许可证明确
禁止未经授权使用代码与资源，也禁止未授权商业用途。《泺栋传奇》不复制
JYNew 源码、资源、剧情、角色、武学名称或配置文件，只借鉴公开描述的系统
边界并在 Godot 4 中原创实现。

## 值得借鉴的系统边界

- 数据驱动：角色、物品、武学、任务、掉落表与地图入口使用独立配置；
- 剧情驱动：把对白、条件、奖励、分支和场景操作组织为可扩展指令；
- 场景串接：每张地图独立加载，通过出口和剧情事件切换；
- 异步流程：对白、移动、战斗、奖励和过场按序等待，避免回调嵌套；
- Mod 分层：引擎核心、原创世界数据和用户扩展包互相隔离；
- 战斗 AI：感知、追击、技能选择和脱战使用可替换策略。

## Godot 原创实现映射

| JYNew 公开架构概念 | 《泺栋传奇》实现 |
| --- | --- |
| ScriptableObject 配置 | Godot `Resource` + JSON 数据包 |
| Lua/可视化剧情脚本 | 原创事件指令资源与可选 Lua 沙箱 |
| 每地图一个 Unity Scene | 每地图一个 Godot 场景 + Tiled TMX |
| AssetBundle | PCK/ZIP Mod 包 + manifest |
| UGUI | Godot Control 主题与可复用界面组件 |
| UniTask 流程 | `await` 信号与可取消剧情执行器 |
| 回合战棋 AI | 鼠标 ARPG 的行为树/状态机 AI |

## 第一阶段数据结构

- `WorldManifest`：世界版本、起始地图、扩展包依赖；
- `MapDefinition`：TMX、出生点、出口、音乐、环境标签；
- `ActorDefinition`：属性、阵营、外观、武学和掉落表；
- `SkillDefinition`：距离、冷却、消耗、命中、动作与特效；
- `QuestDefinition`：阶段、条件、事件指令、分支和奖励；
- `DialogueDefinition`：说话人、文本、条件和选项；
- `LootTable`：权重、数量、品质与条件；
- `SaveSnapshot`：玩家状态、任务状态、地图状态和 Mod 版本。

## 禁止迁移内容

- JYNew 的任何源代码、Unity 场景、Prefab、模型、贴图、音频和第三方插件；
- 金庸人物、门派、武学、地名、对白和剧情；
- 样例 Mod 的配置、数值和事件脚本；
- 未经单独授权的截图、宣传图和社区素材。
