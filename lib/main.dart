import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import 'data/disk_usage.dart';

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
  List<DiskUsage> _disks = const [];
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
    final items = <MenuItem>[
      MenuItem(
        key: 'workspace_info',
        label: _scanning
            ? '扫描中…'
            : 'Workspace: ${DiskUsage.formatBytes(_workspaceBytes ?? 0)}',
      ),
    ];
    if (_disks.isNotEmpty) {
      items.add(MenuItem.separator());
      items.add(MenuItem(
        key: 'disks_header',
        label: '磁盘占用',
        disabled: true,
      ));
      for (final d in _disks) {
        items.add(MenuItem(
          key: 'disk_${d.mountPoint}',
          label: '${d.mountPoint}  '
              '${d.usedPercent.toStringAsFixed(0)}%  '
              '(${d.availableLabel} 可用)',
          disabled: true,
        ));
      }
    }
    items.addAll([
      MenuItem.separator(),
      MenuItem(key: 'refresh', label: _scanning ? '扫描中…' : '刷新'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);
    await trayManager.setContextMenu(Menu(items: items));
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    await _updateTrayMenu();
    final disksFuture = DiskCollector.collect();
    var bytes = _workspaceBytes;
    try {
      final result = await Process.run('du', ['-sb', _workspacePath]);
      if (result.exitCode == 0) {
        bytes = int.tryParse((result.stdout as String).trim().split('\t').first);
      }
    } catch (_) {}
    final disks = await disksFuture;
    if (mounted) setState(() => _scanning = false);
    if (bytes != null && bytes != _workspaceBytes) {
      _workspaceBytes = bytes;
    }
    _disks = disks;
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

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}