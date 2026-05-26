import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  AppState({ApiService? apiService}) : _api = apiService ?? ApiService();

  ApiService _api;
  bool _settingsLoaded = false;

  Uint8List? _uploadedImageBytes;
  String? _uploadedImagePath;
  EyebrowStyle? _selectedStyle;
  Uint8List? _resultBeforeBytes;
  Uint8List? _resultAfterBytes;
  String? _resultEngine;
  bool _isApplying = false;
  String? _errorMessage;
  String? _apiBaseUrl;
  String? _serverStatusMessage;
  bool _isCheckingServer = false;
  int _currentTab = 0;

  Uint8List? get uploadedImageBytes => _uploadedImageBytes;
  String? get uploadedImagePath => _uploadedImagePath;
  EyebrowStyle? get selectedStyle => _selectedStyle;
  Uint8List? get resultBeforeBytes => _resultBeforeBytes ?? _uploadedImageBytes;
  Uint8List? get resultAfterBytes => _resultAfterBytes;
  String? get resultEngine => _resultEngine;
  bool get isApplying => _isApplying;
  String? get errorMessage => _errorMessage;
  String? get apiBaseUrl => _apiBaseUrl;
  String? get serverStatusMessage => _serverStatusMessage;
  bool get isCheckingServer => _isCheckingServer;
  int get currentTab => _currentTab;
  bool get hasUploadedImage => _uploadedImageBytes != null;
  bool get hasResult => _resultAfterBytes != null;
  bool get settingsLoaded => _settingsLoaded;

  Future<void> loadSettings() async {
    await ApiConfig.loadSavedBaseUrl();
    _apiBaseUrl = ApiConfig.savedBaseUrl ?? ApiConfig.resolveBaseUrl();
    _api = ApiService(baseUrl: _apiBaseUrl);
    _settingsLoaded = true;
    notifyListeners();
  }

  Future<void> setApiBaseUrl(String url) async {
    await ApiConfig.saveBaseUrl(url);
    _apiBaseUrl = ApiConfig.savedBaseUrl ?? ApiConfig.resolveBaseUrl();
    _api = ApiService(baseUrl: _apiBaseUrl);
    _serverStatusMessage = null;
    notifyListeners();
  }

  Future<bool> checkServerHealth() async {
    _isCheckingServer = true;
    _serverStatusMessage = null;
    notifyListeners();

    try {
      final health = await _api.health();
      final engine = health['engine'] as String? ?? 'unknown';
      final message = health['message'] as String? ?? '';
      _serverStatusMessage = '연결됨 · $engine · $message';
      _isCheckingServer = false;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _serverStatusMessage = error.message;
      _isCheckingServer = false;
      notifyListeners();
      return false;
    } catch (_) {
      _serverStatusMessage = '서버 연결 실패. Mac IP와 API 실행 여부를 확인해주세요.';
      _isCheckingServer = false;
      notifyListeners();
      return false;
    }
  }

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setUploadedImage({required Uint8List bytes, String? path}) {
    _uploadedImageBytes = bytes;
    _uploadedImagePath = path;
    _resultBeforeBytes = null;
    _resultAfterBytes = null;
    _resultEngine = null;
    _selectedStyle = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearUploadedImage() {
    _uploadedImageBytes = null;
    _uploadedImagePath = null;
    _resultBeforeBytes = null;
    _resultAfterBytes = null;
    _resultEngine = null;
    _selectedStyle = null;
    _errorMessage = null;
    notifyListeners();
  }

  void selectStyle(EyebrowStyle style) {
    _selectedStyle = style;
    notifyListeners();
  }

  Future<bool> applyStyle() async {
    if (_uploadedImageBytes == null || _selectedStyle == null) {
      return false;
    }

    _isApplying = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.applyStyle(
        imageBytes: _uploadedImageBytes!,
        styleId: _selectedStyle!.id,
        filename: _uploadedImagePath?.split('/').last ?? 'upload.jpg',
      );

      _resultBeforeBytes = result.beforeBytes;
      _resultAfterBytes = result.afterBytes;
      _resultEngine = result.engine;
      _isApplying = false;
      _currentTab = 3;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _isApplying = false;
      notifyListeners();
      return false;
    } catch (error) {
      _errorMessage = '서버 연결에 실패했습니다. 마이 탭에서 API 주소를 확인해주세요.';
      _isApplying = false;
      notifyListeners();
      return false;
    }
  }

  void resetResult() {
    _resultBeforeBytes = null;
    _resultAfterBytes = null;
    _resultEngine = null;
    _selectedStyle = null;
    _errorMessage = null;
    notifyListeners();
  }
}
