import 'package:package_info_plus/package_info_plus.dart';
import 'api_client.dart';

class VersionConfig {
  final int minBuild;
  final String latestVersion;
  final String updateUrl;

  const VersionConfig({
    required this.minBuild,
    required this.latestVersion,
    required this.updateUrl,
  });
}

class VersionCheck {
  static const String appKey = 'customer';

  static Future<VersionConfig?> fetchConfig() async {
    try {
      final data = await ApiClient.get('/api/app/config');
      final app = data[appKey];
      if (app is Map<String, dynamic>) {
        return VersionConfig(
          minBuild: (app['minBuild'] as num?)?.toInt() ?? 0,
          latestVersion: app['latestVersion']?.toString() ?? '',
          updateUrl: app['updateUrl']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<VersionConfig?> fetchRequiredConfig() async {
    final config = await fetchConfig();
    if (config == null) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      if (currentBuild < config.minBuild) return config;
    } catch (_) {}
    return null;
  }
}
