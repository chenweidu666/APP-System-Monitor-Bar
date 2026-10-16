import 'dart:io';

import '../config/monitor_config.dart';

class WorkspaceScanResult {
  const WorkspaceScanResult({
    required this.bytes,
    required this.scannedAt,
    this.error,
  });

  final int bytes;
  final DateTime scannedAt;
  final String? error;

  bool get ok => error == null;
}

class WorkspaceScanner {
  int? _cachedBytes;
  DateTime? _cachedAt;
  String? _lastError;

  int? get cachedBytes => _cachedBytes;
  DateTime? get cachedAt => _cachedAt;
  String? get lastError => _lastError;

  bool shouldRescan(DateTime now) {
    final at = _cachedAt;
    if (at == null) return true;
    return now.difference(at) >= MonitorConfig.workspaceRefreshInterval;
  }

  /// 从 du -sb 的 stdout 提取总字节数；取最后一行的数字，无有效数字返回 null。
  static int? _parseBytes(String stdout) {
    final lines = stdout.trim().split('\n');
    for (var i = lines.length - 1; i >= 0; i--) {
      final raw = lines[i].trim().split(RegExp(r'\s+')).first;
      final bytes = int.tryParse(raw);
      if (bytes != null) return bytes;
    }
    return null;
  }

  Future<WorkspaceScanResult> scan({bool force = false}) async {
    final now = DateTime.now();
    if (!force && !shouldRescan(now) && _cachedBytes != null) {
      return WorkspaceScanResult(
        bytes: _cachedBytes!,
        scannedAt: _cachedAt!,
      );
    }

    try {
      final result = await Process.run('du', [
        '-sb',
        MonitorConfig.workspacePath,
      ]);
      // du 遇到个别无权限子目录会返回非 0，但 stdout 仍输出可用总量，
      // 因此只要 stdout 能解析出数字就采用，避免整体显示为 0。
      final bytes = _parseBytes(result.stdout as String);
      if (bytes != null) {
        _cachedBytes = bytes;
        _cachedAt = now;
        _lastError = null;
        return WorkspaceScanResult(bytes: bytes, scannedAt: now);
      }
      final stderr = (result.stderr as String).trim();
      _lastError = stderr.isEmpty ? 'du 无输出' : stderr;
      return WorkspaceScanResult(
        bytes: _cachedBytes ?? 0,
        scannedAt: now,
        error: _lastError,
      );
    } catch (e) {
      _lastError = e.toString();
      return WorkspaceScanResult(
        bytes: _cachedBytes ?? 0,
        scannedAt: now,
        error: _lastError,
      );
    }
  }
}
