import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_logger.dart';

class UmamiAnalyticsService {
  static final UmamiAnalyticsService _instance =
      UmamiAnalyticsService._internal();

  factory UmamiAnalyticsService() {
    return _instance;
  }

  UmamiAnalyticsService._internal();

  String? _apiUrl;
  String? _websiteId;
  String? _hostname;
  String? _userAgent;
  String? _screenResolution;
  String? _language;

  bool _isInitialized = false;

  final List<Function> _pendingEvents = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    _apiUrl = dotenv.env['UMAMI_API_URL'];
    _websiteId = dotenv.env['UMAMI_WEBSITE_ID'];
    _hostname = dotenv.env['UMAMI_HOSTNAME'] ?? 'lectio-app';

    appLogger.d('🔍 Umami Config - ID: $_websiteId, Host: $_hostname');

    if (_apiUrl == null || _websiteId == null) {
      appLogger.w('⚠️ Umami Analytics not configured (missing env vars)');
      return;
    }

    // Prepare static data
    await _loadDeviceInfo();
    _loadScreenInfo();

    _isInitialized = true;
    appLogger.i('🚀 Umami Analytics Initialized: $_apiUrl');

    // Process pending events
    if (_pendingEvents.isNotEmpty) {
      appLogger.i(
        '🚀 Processing ${_pendingEvents.length} pending Umami events',
      );
      for (final event in _pendingEvents) {
        event();
      }
      _pendingEvents.clear();
    }
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String osVersion = '';
    String deviceModel = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      osVersion = 'Android ${androidInfo.version.release}';
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      osVersion = 'iOS ${iosInfo.systemVersion}';
      deviceModel = iosInfo.name;
    }

    // Construct a User-Agent like string
    _userAgent =
        'LectioDivina/${packageInfo.version} ($osVersion; $deviceModel)';
    _language = Platform.localeName.replaceAll('_', '-');
  }

  void _loadScreenInfo() {
    final dispatcher = PlatformDispatcher.instance;
    final view = dispatcher.views.first;
    final physicalSize = view.physicalSize;
    // Physical pixels
    _screenResolution =
        '${physicalSize.width.toInt()}x${physicalSize.height.toInt()}';
  }

  Future<void> trackPageView({
    required String path,
    String? title,
    String? referrer,
  }) async {
    if (!_isInitialized) {
      appLogger.d('⏳ Umami not initialized, queuing page view for: $path');
      _pendingEvents.add(
        () => trackPageView(path: path, title: title, referrer: referrer),
      );
      return;
    }

    final payload = {
      'website': _websiteId,
      'hostname': _hostname,
      'screen': _screenResolution,
      'language': _language,
      'title': title ?? path,
      'url': path,
      'referrer': referrer ?? '',
    };

    await _sendRequest(payload, type: 'event');
  }

  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? eventData,
  }) async {
    if (!_isInitialized) {
      appLogger.d('⏳ Umami not initialized, queuing event: $eventName');
      _pendingEvents.add(() => trackEvent(eventName, eventData: eventData));
      return;
    }

    final payload = {
      'website': _websiteId,
      'hostname': _hostname,
      'screen': _screenResolution,
      'language': _language,
      'url': '/', // Events usually need a URL context
      'name': eventName,
      'data': eventData,
    };

    await _sendRequest(payload, type: 'event');
  }

  Future<void> _sendRequest(
    Map<String, dynamic> payload, {
    required String type,
  }) async {
    try {
      final uri = Uri.parse('$_apiUrl/api/send');

      final body = jsonEncode({'payload': payload, 'type': type});

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent ?? 'LectioApp',
        },
        body: body,
      );

      appLogger.d('📤 Umami Request: $uri');
      appLogger.d('📤 Payload: $body');
      appLogger.d(
        '📥 Umami Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode != 200) {
        appLogger.w(
          '⚠️ Umami Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      appLogger.w('⚠️ Umami Exception: $e');
    }
  }
}
