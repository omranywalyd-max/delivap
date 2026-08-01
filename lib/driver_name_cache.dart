import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DriverNameCache {
  static const _key = 'driver_names_cache';
  static const int _maxSize = 500;
  static Map<String, String> _cache = LinkedHashMap<String, String>(
    equals: (a, b) => a == b,
    hashCode: (e) => e.hashCode,
  );

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _cache = Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
  }

  static String? getName(String driverId) => _cache[driverId];

  static Future<void> save(String driverId, String name) async {
    if (driverId.isEmpty || name.isEmpty || name == 'سائق') return;
    if (_cache[driverId] == name) return;
    _cache[driverId] = name;
    if (_cache.length > _maxSize) {
      final first = _cache.keys.first;
      _cache.remove(first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_cache));
    } catch (_) {}
  }

  static Future<void> saveAll(Map<String, String> names) async {
    bool changed = false;
    for (final e in names.entries) {
      if (e.value.isNotEmpty && e.value != 'سائق' && _cache[e.key] != e.value) {
        _cache[e.key] = e.value;
        if (_cache.length > _maxSize) {
          final first = _cache.keys.first;
          _cache.remove(first);
        }
        changed = true;
      }
    }
    if (changed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(_cache));
      } catch (_) {}
    }
  }
}
