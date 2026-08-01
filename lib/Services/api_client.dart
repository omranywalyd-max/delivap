import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'env_config.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static String? _customToken;

  static Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_customToken != null) {
      headers['Authorization'] = 'Bearer $_customToken';
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static void setToken(String? token) {
    _customToken = token;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final res = await http.get(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
      ).timeout(EnvConfig.apiTimeout);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return <String, dynamic>{};
      } else {
        throw Exception('خطأ من السيرفر: ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  static Future<List<dynamic>> getList(String path) async {
    try {
      final res = await http.get(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
      ).timeout(EnvConfig.apiTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is List<dynamic>) return decoded;
      }
      return <dynamic>[];
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map body) async {
    try {
      final res = await http.post(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.body.trim().startsWith('<')) {
        throw Exception('خطأ من السيرفر (${res.statusCode})');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('فشل إرسال البيانات (${res.statusCode})');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> put(String path, Map body) async {
    try {
      final res = await http.put(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.body.trim().startsWith('<')) {
        throw Exception('خطأ من السيرفر (${res.statusCode})');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('فشل تحديث البيانات (${res.statusCode})');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final res = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
      ).timeout(EnvConfig.apiTimeout);
      if (res.body.trim().startsWith('<')) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  static Future<List<dynamic>> postList(String path, Map body) async {
    try {
      final res = await http.post(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.body.trim().startsWith('<')) {
        return <dynamic>[];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
      return <dynamic>[];
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  static Future<List<dynamic>> putList(String path, Map body) async {
    try {
      final res = await http.put(
        Uri.parse('${EnvConfig.baseUrl}$path'),
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.body.trim().startsWith('<')) {
        return <dynamic>[];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) return decoded;
      return <dynamic>[];
    } catch (e) {
      throw Exception('فشل الاتصال بالسيرفر: $e');
    }
  }

  static Future<bool> deleteUpload(String filename) async {
    try {
      final res = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}/api/upload/$filename'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String> upload(File file) async {
    try {
      final raw = await file.readAsBytes();
      Uint8List bytes;
      final isPng = file.path.toLowerCase().endsWith('.png');
      String filename = isPng ? 'upload.png' : 'upload.jpg';
      try {
        final decoded = img.decodeImage(raw);
        if (decoded != null) {
          // ✅ resize: نزل الأبعاد لحجم معقول (1200px أقصى عرض)
          //    عشان الصور ما تبقاش 4000×3000 وتستهلك bandwidth + CPU + RAM
          final resized = (decoded.width > 1200 || decoded.height > 1200)
              ? img.copyResize(decoded,
                  width: decoded.width >= decoded.height ? 1200 : null,
                  height: decoded.height > decoded.width ? 1200 : null)
              : decoded;
          if (isPng) {
            bytes = Uint8List.fromList(img.encodePng(resized));
          } else {
            bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
          }
          if (bytes.length > 25 * 1024 * 1024) {
            return '';
          }
        } else {
          if (raw.length > 25 * 1024 * 1024) {
            return '';
          }
          bytes = raw;
        }
      } catch (e) {
        if (raw.length > 25 * 1024 * 1024) return '';
        bytes = raw;
      }

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final req = http.MultipartRequest(
            'POST',
            Uri.parse('${EnvConfig.baseUrl}/api/upload'),
          );
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            req.headers['Authorization'] = 'Bearer $token';
          }
          final mime = isPng ? MediaType('image', 'png') : MediaType('image', 'jpeg');
          req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: mime));
          final res = await req.send().timeout(const Duration(seconds: 60));
          final body = await res.stream.bytesToString();
          if (res.statusCode == 200) {
            final result = jsonDecode(body);
            return result['url'] as String? ?? '';
          }
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
