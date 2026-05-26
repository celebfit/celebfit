import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

const apiBaseUrlPrefsKey = 'celebfit_api_base_url';

class ApplyStyleResult {
  const ApplyStyleResult({
    required this.beforeBytes,
    required this.afterBytes,
    required this.styleId,
    required this.styleName,
    required this.engine,
  });

  final Uint8List beforeBytes;
  final Uint8List afterBytes;
  final String styleId;
  final String styleName;
  final String engine;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.resolveBaseUrl();

  final String baseUrl;

  Future<List<EyebrowStyle>> fetchStyles() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/v1/styles'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException('스타일 목록을 불러오지 못했습니다.', statusCode: response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final styles = (body['styles'] as List<dynamic>)
        .map((item) => _styleFromJson(item as Map<String, dynamic>))
        .toList();
    return styles;
  }

  Future<ApplyStyleResult> applyStyle({
    required Uint8List imageBytes,
    required String styleId,
    String filename = 'upload.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/apply'),
    );
    request.fields['style_id'] = styleId;
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      var message = '스타일 적용에 실패했습니다.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {}
      throw ApiException(message, statusCode: response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ApplyStyleResult(
      beforeBytes: base64Decode(body['before_image_base64'] as String),
      afterBytes: base64Decode(body['after_image_base64'] as String),
      styleId: body['style_id'] as String,
      styleName: body['style_name'] as String,
      engine: body['engine'] as String? ?? 'unknown',
    );
  }

  Future<Map<String, dynamic>> health() async {
    final response = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ApiException('API 서버에 연결할 수 없습니다.', statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  EyebrowStyle _styleFromJson(Map<String, dynamic> json) {
    final known = kEyebrowStyles.where((s) => s.id == json['id']).toList();
    if (known.isNotEmpty) {
      return known.first;
    }
    final tags = (json['tags'] as List<dynamic>).cast<String>();
    return EyebrowStyle(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['label'] as String? ?? json['name'] as String,
      tags: tags,
      mockColor: const Color(0xFFC4A882),
    );
  }
}

class ApiConfig {
  static const String envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _savedBaseUrl;

  static Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _savedBaseUrl = prefs.getString(apiBaseUrlPrefsKey);
  }

  static Future<void> saveBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(apiBaseUrlPrefsKey);
      _savedBaseUrl = null;
    } else {
      await prefs.setString(apiBaseUrlPrefsKey, trimmed);
      _savedBaseUrl = trimmed;
    }
  }

  static String? get savedBaseUrl => _savedBaseUrl;

  static String resolveBaseUrl() {
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    if (_savedBaseUrl != null && _savedBaseUrl!.isNotEmpty) {
      return _savedBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://127.0.0.1:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
