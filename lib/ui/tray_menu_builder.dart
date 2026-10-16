import 'package:tray_manager/tray_manager.dart';

import '../data/disk_usage.dart';
import '../data/workspace_scanner.dart';
import '../data/vm_usage.dart';
import 'disk_bar.dart';

class TrayMenuBuilder {
  static List<MenuItem> build({
    required List<DiskUsage> disks,
    required List<VmDiskUsage> vmDisks,
    required WorkspaceScanner workspace,
    required bool scanningDisks,
    required bool scanningWorkspace,
    DateTime? diskUpdatedAt,
  }) {
    final items = <MenuItem>[
      MenuItem(key: 'header', label: '空间监控', disabled: true),
    ];

    final wsBytes = workspace.cachedBytes;
    if (scanningWorkspace && wsBytes == null) {
      items.add(MenuItem(
        key: 'workspace',
        label: 'Workspace  扫描中…',
        disabled: true,
      ));
    } else if (wsBytes != null) {
      items.add(MenuItem(
        key: 'workspace',
        label: 'Workspace  ${DiskUsage.formatBytes(wsBytes)}',
        disabled: true,
      ));
      if (workspace.lastError != null) {
        items.add(MenuItem(
          key: 'workspace_err',
          label: '  du: ${workspace.lastError}',
          disabled: true,
        ));
      }
    }

    if (disks.isEmpty && scanningDisks) {
      items.add(MenuItem(
        key: 'disk_loading',
        label: '分区  读取中…',
        disabled: true,
      ));
    } else if (disks.isNotEmpty) {
      items.add(MenuItem.separator());
      final root = DiskUsage.pickRoot(disks);
      final bar = DiskBarView.build(root, wsBytes ?? 0);

      if (bar.warning != null) {
        items.add(MenuItem(
          key: 'warn',
          label: bar.warning!,
          disabled: true,
        ));
      }

      items.add(MenuItem(
        key: 'disk_summary',
        label: bar.summaryLine,
        disabled: true,
      ));
      items.add(MenuItem(
        key: 'disk_bar',
        label: bar.barLine,
        disabled: true,
      ));
      items.add(MenuItem(
        key: 'disk_legend',
        label: bar.legendLine,
        disabled: true,
      ));

      final others = disks.where((d) => d.mountPoint != root.mountPoint);
      for (final d in others) {
        items.add(MenuItem(
          key: 'disk_${d.mountPoint}',
          label: _compactDiskLine(d),
          disabled: true,
        ));
      }
    }

    if (vmDisks.isNotEmpty) {
      items.add(MenuItem.separator());
      items.add(MenuItem(
        key: 'vm_header',
        label: '虚拟机磁盘  ${vmDisks.length} 个',
        disabled: true,
      ));
      for (final vm in vmDisks) {
        items.add(MenuItem(
          key: 'vm_${vm.domain}_${vm.target}',
          label: '${vm.domain}/${vm.target}  ${vm.allocatedLabel}',
          disabled: true,
        ));
      }
    }

    items.add(MenuItem.separator());

    final stamp = _formatUpdated(diskUpdatedAt, workspace.cachedAt);
    if (stamp.isNotEmpty) {
      items.add(MenuItem(key: 'updated', label: stamp, disabled: true));
    }

    final busy = scanningDisks || scanningWorkspace;
    items.addAll([
      MenuItem(
        key: 'refresh',
        label: busy ? '刷新中…' : '↻ 刷新',
        disabled: busy,
      ),
      MenuItem(
        key: 'open_workspace',
        label: '打开 Workspace 目录',
      ),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);

    return items;
  }

  static String _compactDiskLine(DiskUsage d) {
    return '${d.mountPoint}  ${d.usedPercent.toStringAsFixed(0)}%'
        '  (${d.availableLabel} 可用)';
  }

  static String _formatUpdated(DateTime? diskAt, DateTime? wsAt) {
    final parts = <String>[];
    if (diskAt != null) {
      parts.add('分区 ${_hhmm(diskAt)}');
    }
    if (wsAt != null) {
      parts.add('WS ${_hhmm(wsAt)}');
    }
    if (parts.isEmpty) return '';
    return '更新 ${parts.join(' · ')}';
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
