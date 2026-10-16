import '../config/monitor_config.dart';
import '../data/disk_usage.dart';

class DiskBarView {
  const DiskBarView({
    required this.barLine,
    required this.summaryLine,
    required this.legendLine,
    required this.warning,
  });

  final String barLine;
  final String summaryLine;
  final String legendLine;
  final String? warning;

  static DiskBarView build(DiskUsage disk, int workspaceBytes) {
    final total = disk.totalBytes;
    if (total <= 0) {
      return const DiskBarView(
        barLine: '[------------------------]',
        summaryLine: '数据不可用',
        legendLine: '',
        warning: null,
      );
    }

    final used = disk.usedBytes;
    final w = workspaceBytes.clamp(0, used);
    final other = used - w;
    const width = MonitorConfig.barWidth;

    var wb = (w / total * width).round();
    var ob = (other / total * width).round();
    if (wb + ob > width) wb = width - ob;
    if (wb < 0) wb = 0;
    final fb = width - wb - ob;

    final bar = '█' * wb + '▓' * ob + '░' * fb;
    final warning = _warningFor(disk);

    return DiskBarView(
      barLine: '[$bar]',
      summaryLine:
          '${disk.mountPoint}  已用 ${disk.usedPercent.toStringAsFixed(0)}%  '
          '${DiskUsage.formatBytes(used)}/${DiskUsage.formatBytes(total)}',
      legendLine: '█ WS ${DiskUsage.formatBytes(w)}'
          '  ·  ▓ ${DiskUsage.formatBytes(other)}'
          '  ·  ░ ${disk.availableLabel}',
      warning: warning,
    );
  }

  static String? _warningFor(DiskUsage disk) {
    if (disk.availableBytes < MonitorConfig.lowSpaceBytes) {
      return '⚠ 剩余不足 ${disk.availableLabel}';
    }
    if (disk.usedPercent >= MonitorConfig.highUsedPercent) {
      return '⚠ 已用 ${disk.usedPercent.toStringAsFixed(0)}%，空间紧张';
    }
    return null;
  }
}
