import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import '../env_config.dart';

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
    final url = Uri.parse('${EnvConfig.baseUrl}$path');
    try {
      final res = await http.get(url, headers: await _headers())
          .timeout(EnvConfig.apiTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('API GET error: $e');
      return <String, dynamic>{};
    }
  }

  static Future<List<dynamic>> getList(String path) async {
    final url = Uri.parse('${EnvConfig.baseUrl}$path');
    try {
      final res = await http.get(url, headers: await _headers())
          .timeout(EnvConfig.apiTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is List<dynamic>) return decoded;
      }
      return <dynamic>[];
    } catch (e) {
      debugPrint('API GET list error: $e');
      return <dynamic>[];
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map body) async {
    final url = Uri.parse('${EnvConfig.baseUrl}$path');
    try {
      final res = await http.post(
        url,
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      debugPrint('API POST error: ${res.statusCode} ${res.body}');
      throw Exception('فشل إرسال البيانات (${res.statusCode})');
    } catch (e) {
      debugPrint('API POST error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> put(String path, Map body) async {
    final url = Uri.parse('${EnvConfig.baseUrl}$path');
    try {
      final res = await http.put(
        url,
        headers: await _headers(),
        body: utf8.encode(jsonEncode(body)),
      ).timeout(EnvConfig.apiTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('API PUT error: ${res.statusCode} ${res.body}');
        throw Exception('فشل تحديث البيانات (${res.statusCode})');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('API PUT error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final url = Uri.parse('${EnvConfig.baseUrl}$path');
    try {
      final res = await http.delete(url, headers: await _headers())
          .timeout(EnvConfig.apiTimeout);
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('API DELETE error: $e');
      return <String, dynamic>{};
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
      debugPrint('API deleteUpload error: $e');
      return false;
    }
  }

  static Future<void> deleteImageUrl(String url) async {
    if (url.contains('/uploads/')) {
      await deleteUpload(url.split('/').last);
    }
  }

  static Future<void> deleteImageUrls(List<String> urls) async {
    for (final url in urls) {
      await deleteImageUrl(url);
    }
  }

  static Future<String> upload(File file) async {
    try {
      final raw = await file.readAsBytes();
      debugPrint('API upload: original size ${raw.length} bytes');

      Uint8List bytes;
      final isPng = file.path.toLowerCase().endsWith('.png');
      String filename = isPng ? 'upload.png' : 'upload.jpg';
      try {
        final decoded = img.decodeImage(raw);
        if (decoded != null) {
          if (isPng) {
            bytes = Uint8List.fromList(img.encodePng(decoded));
          } else {
            bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
          }
          debugPrint('API upload: compressed ${raw.length} -> ${bytes.length} bytes, ${decoded.width}x${decoded.height}');
          if (bytes.length > 25 * 1024 * 1024) {
            debugPrint('API upload: compressed file too large (${bytes.length} bytes)');
            return '';
          }
        } else {
          if (raw.length > 25 * 1024 * 1024) {
            debugPrint('API upload: original file too large (${raw.length} bytes)');
            return '';
          }
          bytes = raw;
          debugPrint('API upload: decodeImage returned null, sending original');
        }
      } catch (e) {
        debugPrint('API upload: image processing failed: $e');
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
          debugPrint('API upload error (attempt ${attempt + 1}): status ${res.statusCode}, body: $body');
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('API upload network error (attempt ${attempt + 1}): $e');
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }
      return '';
    } catch (e) {
      debugPrint('API upload fatal error: $e');
      return '';
    }
  }
}
