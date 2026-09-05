import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Tlačidlo inbox správy — text + kľúč obrazovky (prázdny = len zavrieť).
class InboxButton {
  final String label;
  final String screenKey;
  InboxButton({required this.label, required this.screenKey});
  factory InboxButton.fromJson(Map<String, dynamic> j) => InboxButton(
        label: (j['label'] ?? '').toString(),
        screenKey: (j['screen_key'] ?? '').toString(),
      );
}

/// Jedna inbox správa na zobrazenie (už lokalizovaná backendom).
class InboxMessage {
  final String id;
  final String frequency;
  final String? imageUrl;
  final String? title;
  final String? body;
  final List<InboxButton> buttons;

  InboxMessage({
    required this.id,
    required this.frequency,
    this.imageUrl,
    this.title,
    this.body,
    required this.buttons,
  });

  bool get isEmpty => (title == null || title!.isEmpty) && (body == null || body!.isEmpty);
}

/// Klient pre in-app popup správy (Inbox). Kľúč zostáva na serveri; appka len
/// pýta „čo mám zobraziť" a hlási videné/akcie.
class InboxService {
  InboxService._();
  static final InboxService instance = InboxService._();

  String get _backendUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  /// Jazyk appky → kľúč obsahu (cs→cz, pt→pt-br).
  String _localeKey(String languageCode) {
    final lc = languageCode.toLowerCase();
    if (lc.startsWith('cs') || lc.startsWith('cz')) return 'cz';
    if (lc.startsWith('pt')) return 'pt-br';
    return lc;
  }

  /// FCM token slúži ako identita anonymného zariadenia (device_key).
  Future<String?> _deviceKey() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Vráti aktívnu správu na zobrazenie, alebo null.
  Future<InboxMessage?> fetchActive(String languageCode) async {
    try {
      final platform = Platform.isIOS ? 'ios' : (Platform.isMacOS ? 'macos' : 'android');
      final pkg = await PackageInfo.fromPlatform();
      final version = '${pkg.version}+${pkg.buildNumber}';
      final session = Supabase.instance.client.auth.currentSession;
      final deviceKey = await _deviceKey();

      final uri = Uri.parse('$_backendUrl/api/inbox/active').replace(queryParameters: {
        'platform': platform,
        'app_version': version,
        'lang': _localeKey(languageCode),
        'device_key': ?deviceKey,
      });

      final res = await http.get(
        uri,
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        appLogger.w('inbox/active ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = json['message'];
      if (msg == null) return null;

      final content = (msg['content'] as Map?)?.cast<String, dynamic>() ?? {};
      final buttons = ((content['buttons'] as List?) ?? [])
          .map((b) => InboxButton.fromJson((b as Map).cast<String, dynamic>()))
          .toList();

      final message = InboxMessage(
        id: msg['id'].toString(),
        frequency: (msg['frequency'] ?? 'once').toString(),
        imageUrl: content['image_url']?.toString(),
        title: content['title']?.toString(),
        body: content['body']?.toString(),
        buttons: buttons,
      );
      return message.isEmpty ? null : message;
    } catch (e) {
      appLogger.w('inbox fetchActive failed: $e');
      return null;
    }
  }

  /// Zapíše videné / zavreté / kliknuté (fire-and-forget).
  Future<void> reportSeen(String messageId, String action, {int? buttonIndex}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final deviceKey = await _deviceKey();
      await http.post(
        Uri.parse('$_backendUrl/api/inbox/seen'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'message_id': messageId,
          'action': action,
          'button_index': ?buttonIndex,
          'device_key': ?deviceKey,
        }),
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      appLogger.w('inbox reportSeen failed: $e');
    }
  }
}
