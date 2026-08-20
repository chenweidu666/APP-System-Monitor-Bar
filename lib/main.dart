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
      // 各分区文本行暂不显示（要显示取消注释）
      // for (final d in _disks) {
      //   items.add(MenuItem(
      //     key: 'disk_${d.mountPoint}',
      //     label: '${d.mountPoint}  '
      //         '${d.usedPercent.toStringAsFixed(0)}%  '
      //         '(${d.availableLabel} 可用)',
      //     disabled: true,
      //   ));
      // }
      final root = _disks.firstWhere((d) => d.mountPoint == '/',
          orElse: () => _disks.first);
      items.add(MenuItem(
        key: 'disk_bar',
        label: _buildDiskBar(root, _workspaceBytes ?? 0),
        disabled: true,
      ));
      items.add(MenuItem(
        key: 'disk_bar_legend',
        label: _buildDiskLegend(root, _workspaceBytes ?? 0),
        disabled: true,
      ));
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

  /// 三段进度条（基于根分区 / 总容量）：
  /// █ Workspace 占用 · ▓ 其他已用 · ░ 剩余空间
  String _buildDiskBar(DiskUsage d, int workspaceBytes) {
    const width = 20;
    final total = d.totalBytes;
    if (total <= 0) return '[----]';

    final used = d.usedBytes;
    final w = workspaceBytes.clamp(0, used);
    final other = used - w;

    var wb = (w / total * width).round();
    var ob = (other / total * width).round();
    if (wb + ob > width) wb = width - ob;
    if (wb < 0) wb = 0;
    final fb = width - wb - ob;

    final bar = '█' * wb + '▓' * ob + '░' * fb;
    return '[$bar] 已用 ${d.usedPercent.toStringAsFixed(0)}%  '
        '${DiskUsage.formatBytes(used)}/${DiskUsage.formatBytes(total)}';
  }

  String _buildDiskLegend(DiskUsage d, int workspaceBytes) {
    final used = d.usedBytes;
    final w = workspaceBytes.clamp(0, used);
    final other = used - w;
    return '█ Workspace ${DiskUsage.formatBytes(w)}'
        '  ·  ▓ 其他 ${DiskUsage.formatBytes(other)}'
        '  ·  ░ 剩余 ${d.availableLabel}';
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}