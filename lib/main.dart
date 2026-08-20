import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  runApp(const WorkspaceMonitorApp());
}

class WorkspaceMonitorApp extends StatelessWidget {
  const WorkspaceMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const TrayApp(),
    );
  }
}

class TrayApp extends StatefulWidget {
  const TrayApp({super.key});

  @override
  State<TrayApp> createState() => _TrayAppState();
}

class _TrayAppState extends State<TrayApp> with TrayListener {
  static const _workspacePath = '/home/chenwei/Workspace';
  static const _refreshInterval = Duration(seconds: 60);

  int? _workspaceBytes;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
    _scan();
    Timer.periodic(_refreshInterval, (_) => _scan());
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon('assets/tray_icon.png');
      await _updateTrayMenu();
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
    }
  }

  Future<void> _updateTrayMenu() async {
    final menu = Menu(items: [
      MenuItem(
        key: 'workspace_info',
        label: _scanning
            ? '扫描中…'
            : 'Workspace: ${_fmtBytes(_workspaceBytes ?? 0)}',
      ),
      MenuItem.separator(),
      MenuItem(key: 'refresh', label: _scanning ? '扫描中…' : '刷新'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    await _updateTrayMenu();
    var bytes = _workspaceBytes;
    try {
      final result = await Process.run('du', ['-sb', _workspacePath]);
      if (result.exitCode == 0) {
        bytes = int.tryParse((result.stdout as String).trim().split('\t').first);
      }
    } catch (_) {}
    if (mounted) setState(() => _scanning = false);
    if (bytes != null && bytes != _workspaceBytes) {
      _workspaceBytes = bytes;
    }
    await _updateTrayMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'refresh') {
      _scan();
    } else if (menuItem.key == 'quit') {
      exit(0);
    }
  }

  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}