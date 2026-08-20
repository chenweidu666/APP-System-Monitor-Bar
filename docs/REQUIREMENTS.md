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
  - `刷新`（手动立即扫描一次）
  - `退出`
- 自动刷新：每 **60s** 扫描一次（可配常量 `_refreshInterval`）
- 开机自启：`~/.config/autostart/system_monitor_bar.desktop`

## 5. 非功能需求

- 启动即常驻，资源占用低
- Linux (Ubuntu) 优先
- 只读展示，不做删除/清理功能

## 6. 目录结构

```
11-System-Monitor-Bar/
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

## 7. 里程碑

| # | 内容 | 状态 |
|---|------|------|
| M1 | 托盘图标 + 右键菜单（静态文本） | ✅ |
| M2 | 动态显示 Workspace 大小 + 60s 自动刷新 | ✅ |
| M3 | 开机自启 | ✅ |