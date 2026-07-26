# 泺栋传奇 v0.4.2

## 黑屏修复

- 修复主场景鼠标事件未显式转换为 `InputEventMouseButton` 导致的
  GDScript 类型推断失败
- 修复脚本加载失败后客户端只显示黑色窗口的问题
- GitHub Actions 现在会解析 Godot 验证输出，发现脚本错误立即失败
- Windows 导出后会真实启动 EXE 进行无界面冒烟测试
- 脚本解析失败的构建不再生成安装包或 GitHub Release
