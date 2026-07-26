# 泺栋传奇 v0.3.0

这一版将此前的临时场景替换为可见、可游玩的完整 RPG 地图。

## 新内容

- 直接迁移 MIT 开源项目 `remarkablegames/phaser-rpg` 的完整 Tiled 地图、
  瓦片素材、角色图集和四方向行走动画
- 将迁移场景改造为原创明朝武侠地点“云津渡”
- 保留并整合三类武学、敌人追击、近战判定、伤害数字、碎银掉落和剧情选择
- 修复 Windows Electron 客户端从 `file://` 启动时资源路径错误导致的空白游戏区
- 继续提供无需安装、无需联网的 Windows x64 portable 客户端

## 操作

- 移动：`WASD` 或方向键
- 出招：空格或 `J`
- 也可以使用界面右侧的武学和攻击按钮

## 开源来源

本版直接迁移的地图、瓦片和角色示例素材来自
`remarkablegames/phaser-rpg` 固定提交
`46d12970317baf0875e646efced1eeca59471c0b`，采用 MIT License。
详细清单和许可证见仓库内 `THIRD_PARTY_NOTICES.md` 与
`src/vendor/phaser-rpg/LICENSE`。
