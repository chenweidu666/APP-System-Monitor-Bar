# Workspace 空间监控托盘 — 需求文档

> 版本：v2.0 (2026-08-20)
> 状态：已确认

## 1. 背景

本机日常开发磁盘紧张（Workspace 曾达 422G/846G），需要实时掌握 Workspace 目录占用，
避免频繁手动 `du` 排查。

## 2. 目标

开发一个**纯托盘桌面应用**，在 GNOME 顶栏右侧常驻托盘图标，右键菜单实时显示
Workspace 目录占用，支持手动刷新与退出。无主窗口、无弹窗。

## 3. 技术选型

| 项 | 选择 | 说明 |
|----|------|------|
| 框架 | Flutter (Linux Desktop) | 已启用，见 DESIGN.md |
| 托盘插件 | tray_manager ^0.2.0 | 支持 Linux AppIndicator |
| 数据采集 | `du -sb <Workspace>` | 简单直接，主窗口隐藏 |

## 4. 功能需求

- 托盘图标：GNOME 顶栏右侧常驻
- 菜单项：
  - `Workspace: XXX GB`（当前占用，扫描中显示`扫描中…`）
  - **磁盘占用**（只读，各真实分区一行）：`/ 44% (455G 可用)`、`/boot/efi 3% (1.1G 可用)`
  - **根分区 `/` 三段进度条 + 数值**（基于总容量）：
    - `█` Workspace 占用（蓝）
    - `▓` 其他已用（橙，分区已用减 Workspace）
    - `░` 剩余空间（绿）
    - 格式：`[$bar] 已用 44%  373G/846G` + 图例 `█ Workspace 348G · ▓ 其他 25G · ░ 剩余 455G`
  - `刷新`（手动立即扫描一次）
  - `退出`
- 自动刷新：每 **60s** 扫描一次 Workspace 与各分区占用（可配常量 `_refreshInterval`）
  - Workspace 用 `du -sb`，分区用 `df -P -B1 --local`（排除虚拟文件系统与 snap loop 设备）
- 开机自启：`~/.config/autostart/system_monitor_bar.desktop`

## 5. 非功能需求

- 启动即常驻，资源占用低
- Linux (Ubuntu) 优先
- 只读展示，不做删除/清理功能

## 6. 目录结构

```
11-System-Monitor-Bar/
├── lib/
│   ├── main.dart              # 托盘应用入口
│   └── data/disk_usage.dart   # 磁盘分区占用采集 (df)
├── assets/
│   └── tray_icon.png          # 托盘图标 (64x64)
├── linux/                     # Flutter Linux runner
├── docs/
│   ├── REQUIREMENTS.md
│   └── DESIGN.md
└── ~/.config/autostart/system_monitor_bar.desktop   # 开机自启
```

## 7. 里程碑

| # | 内容 | 状态 |
|---|------|------|
| M1 | 托盘图标 + 右键菜单（静态文本） | ✅ |
| M2 | 动态显示 Workspace 大小 + 60s 自动刷新 | ✅ |
| M3 | 磁盘分区占用监控（所有真实分区比例） | ✅ |
| M4 | 根分区 `/` 三段进度条（Workspace/其他已用/剩余） | ✅ |
| M5 | 开机自启 | ✅ |