# Workspace 空间监控 — 设计文档

> 版本：v2.0 (2026-08-20)
> 技术栈：Flutter (Linux Desktop) + tray_manager

## 1. 需求

开发一个**纯托盘应用**，在 GNOME 顶栏右侧显示小图标，右键菜单显示 Workspace 空间占用，
无主窗口、无弹窗。自动每 60s 刷新，可手动刷新。开机自启。

> 前一版本（v1.0）曾规划顶部悬浮小条 + 详情面板 + 大目录扫描（lib/bar、lib/panel、lib/data），
> 均已按确认的需求删除，仅保留纯托盘形态。

## 2. 功能

| 功能 | 说明 |
|------|------|
| 托盘图标 | GNOME 顶栏右侧常驻，蓝色文件夹图标 |
| 右键菜单 | Workspace 占用 + 磁盘分区占用列表 + 根分区三段进度条 + 刷新 + 退出 |
| Workspace 采集 | `du -sb`，每 60 秒 |
| 分区采集 | `df -P -B1 --local`，与 Workspace 同周期刷新 |
| 三段进度条 | 基于根分区 `/`：█ Workspace · ▓ 其他已用 · ░ 剩余（字符块模拟三色） |
| 手动刷新 | 菜单「刷新」立即扫描一次 |
| 开机自启 | `~/.config/autostart/system_monitor_bar.desktop` |
| 无主窗口 | 主窗口隐藏，仅保留托盘 |

## 3. 技术选型

| 项 | 选择 | 说明 |
|----|------|------|
| 框架 | Flutter 3.44 (stable) | Linux desktop 已启用 |
| 托盘插件 | tray_manager ^0.2.0 | 支持 Linux AppIndicator |
| 数据采集 | `Process.run('du', ['-sb', path])` | 简单直接 |
| 主窗口 | 隐藏 | `SizedBox.shrink()` |

## 4. 目录结构

```
11-System-Monitor-Bar/
├── pubspec.yaml
├── lib/
│   └── main.dart              # 托盘应用入口
├── assets/
│   └── tray_icon.png          # 托盘图标 (64x64)
├── linux/                     # Flutter Linux runner
├── docs/
│   ├── REQUIREMENTS.md
│   └── DESIGN.md
└── ~/.config/autostart/system_monitor_bar.desktop   # 开机自启
```

## 5. 关键实现

### 5.1 托盘初始化
```dart
await trayManager.setIcon('assets/tray_icon.png');
await trayManager.setContextMenu(Menu(items: [
  MenuItem(key: 'info', label: 'Workspace: XXX GB'),
  MenuItem.separator(),
  MenuItem(key: 'refresh', label: '刷新'),
  MenuItem(key: 'quit', label: '退出'),
]));
```

### 5.2 隐藏主窗口
- `lib/main.dart`: `return const SizedBox.shrink();`

### 5.3 数据采集
```dart
final result = await Process.run('du', ['-sb', '/home/chenwei/Workspace']);
// 解析输出: "12345678\t/path" → 12345678 bytes
```

### 5.4 菜单点击
```dart
@override
void onTrayMenuItemClick(MenuItem menuItem) {
  if (menuItem.key == 'refresh') _scan();
  else if (menuItem.key == 'quit') exit(0);
}
```

### 5.5 磁盘分区占用 (lib/data/disk_usage.dart)
```dart
final result = await Process.run('df', ['-P', '-B1', '--local']);
// 过滤: 仅保留 /dev/ 开头的设备，排除 /dev/loop (snap)
// 每行格式: Filesystem total used available capacity Mounted-on
```

### 5.6 三段进度条 (main.dart `_buildDiskBar` / `_buildDiskLegend`)
```dart
// 根分区 / 按总容量切三块:
//   workspace  → '█'  其他已用(used-workspace) → '▓'  剩余 → '░'
// 宽 20 字符, 每格 = total/20
final wb = (workspace / total * width).round();
final ob = (other / total * width).round();
final fb = width - wb - ob;
```

## 6. 里程碑

| # | 内容 | 状态 |
|---|------|------|
| M1 | 托盘图标显示 + 右键菜单（静态文本） | ✅ 完成 |
| M2 | 动态显示 Workspace 大小 + 60s 自动刷新 | ✅ 完成 |
| M3 | 磁盘分区占用监控（所有真实分区比例） | ✅ 完成 |
| M4 | 根分区三段进度条 + 数值图例 | ✅ 完成 |
| M5 | 开机自启 | ✅ 完成 |

## 7. 依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  tray_manager: ^0.2.0

flutter:
  uses-material-design: true
  assets:
    - assets/tray_icon.png
```

系统依赖（已安装）：
- `libayatana-appindicator3-1`
- `gnome-shell-extension-appindicator`