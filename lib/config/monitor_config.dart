/// 空间监控常量（可按本机改路径与刷新间隔）
class MonitorConfig {
  static const workspacePath = '/home/chenwei/Workspace';

  /// df 轻量刷新
  static const diskRefreshInterval = Duration(seconds: 60);

  /// du 较慢，间隔更长；手动刷新仍会立即跑 du
  static const workspaceRefreshInterval = Duration(minutes: 5);

  /// 剩余空间低于此值显示警告
  static const lowSpaceBytes = 50 * 1024 * 1024 * 1024; // 50 GiB

  /// 已用占比高于此值显示警告
  static const highUsedPercent = 85.0;

  static const barWidth = 24;
}
