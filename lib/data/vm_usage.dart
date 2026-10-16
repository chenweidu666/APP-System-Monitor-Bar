import 'dart:io';

import 'disk_usage.dart';

class VmDiskUsage {
  const VmDiskUsage({
    required this.domain,
    required this.target,
    required this.source,
    required this.allocatedBytes,
  });

  final String domain;
  final String target;
  final String source;
  final int allocatedBytes;

  String get allocatedLabel => DiskUsage.formatBytes(allocatedBytes);
}

class VmCollector {
  static const _uri = 'qemu:///system';

  static Future<List<VmDiskUsage>> collect() async {
    final domains = await _run(['list', '--all', '--name']);
    if (domains == null) return [];

    final usages = <VmDiskUsage>[];
    for (final domain in domains
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)) {
      final disks = await _run(['domblklist', domain, '--details']);
      if (disks == null) continue;

      final lines = disks.split('\n');
      for (final line in lines.skip(2)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 4 || parts[0] != 'file' || parts[1] != 'disk') {
          continue;
        }

        final target = parts[2];
        final source = parts.sublist(3).join(' ');
        if (source.isEmpty || source == '-') continue;

        final blockInfo = await _run(['domblkinfo', domain, target]);
        final allocated = _parseValue(blockInfo, 'Allocation:') ??
            await _statSize(source);
        if (allocated == null || allocated <= 0) continue;

        usages.add(VmDiskUsage(
          domain: domain,
          target: target,
          source: source,
          allocatedBytes: allocated,
        ));
      }
    }

    usages.sort((a, b) {
      final domain = a.domain.compareTo(b.domain);
      return domain != 0 ? domain : a.target.compareTo(b.target);
    });
    return usages;
  }

  static Future<String?> _run(List<String> args) async {
    try {
      final result = await Process.run('virsh', ['-c', _uri, ...args]);
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } catch (_) {
      return null;
    }
  }

  static int? _parseValue(String? output, String key) {
    if (output == null) return null;
    for (final line in output.split('\n')) {
      if (!line.trimLeft().startsWith(key)) continue;
      final value = line.substring(line.indexOf(':') + 1).trim();
      return int.tryParse(value.split(RegExp(r'\s+')).first);
    }
    return null;
  }

  static Future<int?> _statSize(String source) async {
    try {
      final result = await Process.run('stat', ['-c', '%s', source]);
      if (result.exitCode != 0) return null;
      return int.tryParse((result.stdout as String).trim());
    } catch (_) {
      return null;
    }
  }
}
