import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static const String _prefix = 'offline_cache_v1_';

  static Future<List<dynamic>> readList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return <dynamic>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) return List<dynamic>.from(decoded);
      return <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  static Future<void> writeList(String key, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(data));
    } catch (_) {}
  }
}
