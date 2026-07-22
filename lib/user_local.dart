import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Services/api_client.dart';

class UserLocal {
  static String? uid;
  static Map<String, dynamic>? _data;
  static String? loadError;
  static bool isIpBanned = false;

  static Map<String, dynamic>? get data => _data;

  static set data(Map<String, dynamic>? value) {
    _data = value;
    if (value != null && uid != null) _save();
  }

  static Future<void> load(String userId) async {
    uid = userId;
    loadError = null;
    isIpBanned = false;
    try {
      await _restore();
      final res = await ApiClient.get('/api/users/$userId');
      if (res.isNotEmpty) {
        final role = res['role'] as String? ?? '';
        if (role == 'owner') {
          loadError = 'هذا الحساب خاص بالتجار، لا يمكن استخدام تطبيق الزبائن';
          _data = null;
          if (uid != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('user_data_$uid');
          }
          return;
        }
        final merged = <String, dynamic>{};
        res.forEach((k, v) {
          if (v != null && v.toString().trim().isNotEmpty) {
            merged[k] = v;
          }
        });
        if (_data != null) {
          _data!.forEach((k, v) {
            if (v != null && v.toString().trim().isNotEmpty && !merged.containsKey(k)) {
              merged[k] = v;
            }
          });
        }
        if (merged['uid'] == null) merged['uid'] = userId;
        _data = merged;
        _save();
      } else {
        loadError = 'لم يتم العثور على حساب زبون بهذا البريد';
        _data = null;
        if (uid != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_data_$uid');
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('404') && msg.contains('deleted')) {
        loadError = 'تم حذف حسابك';
        _data = null;
        if (uid != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_data_$uid');
        }
      } else if (msg.contains('403') || msg.contains('ipBanned') || msg.contains('محظور')) {
        isIpBanned = true;
        loadError = 'تم حظر هذا الجهاز. لا يمكنك استخدام التطبيق.';
      } else {
        loadError = 'فشل الاتصال بالسيرفر';
      }
      if (_data == null) await _restore();
    }
  }

  static void clearError() {
    loadError = null;
    isIpBanned = false;
  }

  static Future<void> save() async {
    if (_data != null && uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_$uid', jsonEncode(_data));
    }
  }

  static Future<void> _save() async {
    await save();
  }

  static Future<void> _restore() async {
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_data_$uid');
    if (raw != null) {
      _data = jsonDecode(raw) as Map<String, dynamic>;
    }
  }

  static Future<void> clear() async {
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('user_data_$uid');
    }
    uid = null;
    _data = null;
  }
}
