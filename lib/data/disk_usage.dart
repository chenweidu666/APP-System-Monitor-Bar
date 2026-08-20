import 'dart:io';

class DiskUsage {
  const DiskUsage({
    required this.mountPoint,
    required this.filesystem,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
  });

  final String mountPoint;
  final String filesystem;
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;

  double get usedPercent =>
      totalBytes == 0 ? 0 : (usedBytes / totalBytes * 100);

  String get availableLabel => formatBytes(availableBytes);

  static String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}${units[i]}';
  }
}

class DiskCollector {
  /// 收集真实磁盘分区占用，排除虚拟文件系统与 snap loop 设备。
  static Future<List<DiskUsage>> collect() async {
    final result = await Process.run('df', ['-P', '-B1', '--local']);
    if (result.exitCode != 0) return [];

    final lines = (result.stdout as String).trim().split('\n');
    final usages = <DiskUsage>[];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      if (parts.length < 6) continue;
      final filesystem = parts[0];
      if (!filesystem.startsWith('/dev/')) continue;
      if (filesystem.startsWith('/dev/loop')) continue;

      final totalBytes = int.tryParse(parts[1]);
      final usedBytes = int.tryParse(parts[2]);
      final availableBytes = int.tryParse(parts[3]);
      if (totalBytes == null || usedBytes == null || availableBytes == null) {
        continue;
      }
      usages.add(DiskUsage(
        mountPoint: parts[5],
        filesystem: filesystem,
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        availableBytes: availableBytes,
      ));
    }
    return usages;
  }
}