import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import 'config/monitor_config.dart';
import 'data/disk_usage.dart';
import 'data/vm_usage.dart';
import 'data/workspace_scanner.dart';
import 'ui/tray_menu_builder.dart';

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
  final _workspace = WorkspaceScanner();
  List<DiskUsage> _disks = const [];
  List<VmDiskUsage> _vmDisks = const [];
  DateTime? _diskUpdatedAt;
  bool _scanningDisks = false;
  bool _scanningWorkspace = false;
  Timer? _diskTimer;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
    _refreshAll(forceWorkspace: true);
    _diskTimer = Timer.periodic(
      MonitorConfig.diskRefreshInterval,
      (_) => _refreshDisks(),
    );
  }

  @override
  void dispose() {
    _diskTimer?.cancel();
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(_trayIconPath());
      await _updateTrayMenu();
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
    }
  }

  String _trayIconPath() {
    // Release 包从开机自启或 nohup 启动时，当前工作目录不一定是项目根目录。
    // 优先使用可执行文件旁的 Flutter 资源绝对路径，开发模式再回退到相对路径。
    final bundledIcon = File('${File(Platform.resolvedExecutable).parent.path}'
        '/data/flutter_assets/assets/tray_icon.png');
    if (bundledIcon.existsSync()) return bundledIcon.path;
    return 'assets/tray_icon.png';
  }

  Future<void> _updateTrayMenu() async {
    final items = TrayMenuBuilder.build(
      disks: _disks,
      vmDisks: _vmDisks,
      workspace: _workspace,
      scanningDisks: _scanningDisks,
      scanningWorkspace: _scanningWorkspace,
      diskUpdatedAt: _diskUpdatedAt,
    );
    await trayManager.setContextMenu(Menu(items: items));
  }

  Future<void> _refreshDisks() async {
    if (_scanningDisks) return;
    setState(() => _scanningDisks = true);
    await _updateTrayMenu();

    final results = await Future.wait([
      DiskCollector.collect(),
      VmCollector.collect(),
    ]);
    if (!mounted) return;
    setState(() {
      _disks = results[0] as List<DiskUsage>;
      _vmDisks = results[1] as List<VmDiskUsage>;
      _diskUpdatedAt = DateTime.now();
      _scanningDisks = false;
    });

    if (_workspace.shouldRescan(DateTime.now())) {
      unawaited(_refreshWorkspace(force: false));
    } else {
      await _updateTrayMenu();
    }
  }

  Future<void> _refreshWorkspace({required bool force}) async {
    if (_scanningWorkspace) return;
    setState(() => _scanningWorkspace = true);
    await _updateTrayMenu();

    await _workspace.scan(force: force);
    if (!mounted) return;
    setState(() => _scanningWorkspace = false);
    await _updateTrayMenu();
  }

  Future<void> _refreshAll({required bool forceWorkspace}) async {
    await _refreshDisks();
    await _refreshWorkspace(force: forceWorkspace);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'refresh':
        _refreshAll(forceWorkspace: true);
        break;
      case 'open_workspace':
        Process.run('xdg-open', [MonitorConfig.workspacePath]);
        break;
      case 'quit':
        exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
