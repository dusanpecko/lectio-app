import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Jazyky obsahu inbox správy (rovnaké kľúče ako web editor).
const List<String> kInboxLangs = ['sk', 'cz', 'en', 'es', 'fr', 'pt-br'];

/// screen_key → čitateľný názov (musí sedieť s web editorom aj popup mapou).
const Map<String, String> kInboxScreenKeys = {
  '': '— len zavrieť —',
  'lectio': 'Lectio divina',
  'rosary': 'Ruženec',
  'adoration': 'Adorácie',
  'novenas': 'Deviatniky',
  'prayers': 'Modlitby',
  'stations': 'Krížové cesty',
  'spiritual-exercises': 'Duchovné cvičenia',
  'news': 'Novinky',
  'donation': 'Podporte / dar',
  'shop': 'E-shop',
};

const List<String> kInboxRoles = [
  'user',
  'pastoral_council',
  'moderator',
  'editor',
  'admin',
];
const List<String> kInboxTiers = ['friend', 'patron', 'founder'];
const List<String> kInboxPlatforms = ['ios', 'android', 'macos'];
const List<String> kInboxStatuses = ['draft', 'active', 'archived'];
const List<String> kInboxFrequencies = ['once', 'until_dismissed', 'every_open'];
const List<String> kInboxAudiences = ['all', 'registered', 'unregistered'];
const List<String> kInboxDonorSegments = [
  'any',
  'one_time',
  'recurring',
  'none',
];

/// Tlačidlo v inbox správe.
class InboxBtn {
  String label;
  String screenKey;
  InboxBtn({this.label = '', this.screenKey = ''});

  factory InboxBtn.fromJson(Map<String, dynamic> j) => InboxBtn(
        label: (j['label'] ?? '').toString(),
        screenKey: (j['screen_key'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'screen_key': screenKey};
}

/// Obsah pre jeden jazyk.
class InboxLangContent {
  String? imageUrl;
  String title;
  String body;
  List<InboxBtn> buttons;

  InboxLangContent({
    this.imageUrl,
    this.title = '',
    this.body = '',
    List<InboxBtn>? buttons,
  }) : buttons = buttons ?? [];

  factory InboxLangContent.fromJson(Map<String, dynamic> j) => InboxLangContent(
        imageUrl: (j['image_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['image_url'] as String?,
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        buttons: ((j['buttons'] as List?) ?? [])
            .map((b) => InboxBtn.fromJson((b as Map).cast<String, dynamic>()))
            .toList(),
      );

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      (imageUrl == null || imageUrl!.isEmpty) &&
      buttons.every((b) => b.label.trim().isEmpty);

  Map<String, dynamic> toJson() => {
        if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
        'title': title,
        'body': body,
        'buttons': buttons
            .where((b) => b.label.trim().isNotEmpty)
            .map((b) => b.toJson())
            .toList(),
      };
}

/// Plná admin inbox správa (všetky polia ako web editor).
class InboxAdminMessage {
  final String? id;
  String status;
  int priority;
  String frequency;
  DateTime? activeFrom;
  DateTime? activeUntil;
  List<String> platforms;
  String minAppVersion;
  String maxAppVersion;
  String audience;
  List<String> roles;
  String donorSegment;
  List<String> subscriptionTiers;
  String defaultLang;
  Map<String, InboxLangContent> content;
  final DateTime? createdAt;

  InboxAdminMessage({
    this.id,
    this.status = 'draft',
    this.priority = 0,
    this.frequency = 'once',
    this.activeFrom,
    this.activeUntil,
    List<String>? platforms,
    this.minAppVersion = '',
    this.maxAppVersion = '',
    this.audience = 'all',
    List<String>? roles,
    this.donorSegment = 'any',
    List<String>? subscriptionTiers,
    this.defaultLang = 'sk',
    Map<String, InboxLangContent>? content,
    this.createdAt,
  })  : platforms = platforms ?? [],
        roles = roles ?? [],
        subscriptionTiers = subscriptionTiers ?? [],
        content = content ?? {};

  factory InboxAdminMessage.empty() => InboxAdminMessage();

  factory InboxAdminMessage.fromJson(Map<String, dynamic> j) {
    final rawContent = (j['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final content = <String, InboxLangContent>{};
    rawContent.forEach((lang, v) {
      if (v is Map) {
        content[lang] = InboxLangContent.fromJson(v.cast<String, dynamic>());
      }
    });
    DateTime? parseDate(dynamic v) =>
        (v == null || v.toString().isEmpty) ? null : DateTime.tryParse(v.toString());

    return InboxAdminMessage(
      id: j['id']?.toString(),
      status: (j['status'] ?? 'draft').toString(),
      priority: (j['priority'] as num?)?.toInt() ?? 0,
      frequency: (j['frequency'] ?? 'once').toString(),
      activeFrom: parseDate(j['active_from']),
      activeUntil: parseDate(j['active_until']),
      platforms: ((j['platforms'] as List?) ?? []).map((e) => e.toString()).toList(),
      minAppVersion: (j['min_app_version'] ?? '').toString(),
      maxAppVersion: (j['max_app_version'] ?? '').toString(),
      audience: (j['audience'] ?? 'all').toString(),
      roles: ((j['roles'] as List?) ?? []).map((e) => e.toString()).toList(),
      donorSegment: (j['donor_segment'] ?? 'any').toString(),
      subscriptionTiers:
          ((j['subscription_tiers'] as List?) ?? []).map((e) => e.toString()).toList(),
      defaultLang: (j['default_lang'] ?? 'sk').toString(),
      content: content,
      createdAt: parseDate(j['created_at']),
    );
  }

  /// Nadpis pre zoznam (default_lang → prvý neprázdny).
  String get displayTitle {
    final def = content[defaultLang];
    if (def != null && def.title.trim().isNotEmpty) return def.title;
    for (final c in content.values) {
      if (c.title.trim().isNotEmpty) return c.title;
    }
    return '(bez nadpisu)';
  }

  Map<String, dynamic> toPayload() {
    final cleanContent = <String, dynamic>{};
    content.forEach((lang, c) {
      if (!c.isEmpty) cleanContent[lang] = c.toJson();
    });
    return {
      'status': status,
      'priority': priority,
      'frequency': frequency,
      'active_from': activeFrom?.toUtc().toIso8601String(),
      'active_until': activeUntil?.toUtc().toIso8601String(),
      'platforms': platforms.isEmpty ? null : platforms,
      'min_app_version': minAppVersion.trim().isEmpty ? null : minAppVersion.trim(),
      'max_app_version': maxAppVersion.trim().isEmpty ? null : maxAppVersion.trim(),
      'audience': audience,
      'roles': roles.isEmpty ? null : roles,
      'donor_segment': donorSegment,
      'subscription_tiers': subscriptionTiers.isEmpty ? null : subscriptionTiers,
      'default_lang': defaultLang,
      'content': cleanContent,
    };
  }
}

/// Klient pre in-app admin správu inbox (Fáza 2). Volá `/api/admin/inbox*`
/// s Bearer tokenom; backend overí rolu `admin` server-side (`requireAdmin`).
class InboxAdminService {
  InboxAdminService._();
  static final InboxAdminService instance = InboxAdminService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  String get _baseUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  Map<String, String> get _headers {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Je prihlásený používateľ administrátor?
  Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final data = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return (data?['role'] as String?) == 'admin';
    } catch (e) {
      appLogger.e('InboxAdminService.isAdmin: $e');
      return false;
    }
  }

  Future<List<InboxAdminMessage>> list() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/admin/inbox'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Načítanie zlyhalo (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ((json['messages'] as List?) ?? [])
        .map((m) => InboxAdminMessage.fromJson((m as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<InboxAdminMessage> getById(String id) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/admin/inbox/$id'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Načítanie zlyhalo (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return InboxAdminMessage.fromJson(
        (json['message'] as Map).cast<String, dynamic>());
  }

  Future<InboxAdminMessage> create(InboxAdminMessage m) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/admin/inbox'),
          headers: _headers,
          body: jsonEncode(m.toPayload()),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Uloženie zlyhalo (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return InboxAdminMessage.fromJson(
        (json['message'] as Map).cast<String, dynamic>());
  }

  Future<InboxAdminMessage> update(String id, InboxAdminMessage m) async {
    final res = await http
        .patch(
          Uri.parse('$_baseUrl/api/admin/inbox/$id'),
          headers: _headers,
          body: jsonEncode(m.toPayload()),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Uloženie zlyhalo (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return InboxAdminMessage.fromJson(
        (json['message'] as Map).cast<String, dynamic>());
  }

  Future<void> delete(String id) async {
    final res = await http
        .delete(Uri.parse('$_baseUrl/api/admin/inbox/$id'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Zmazanie zlyhalo (${res.statusCode})');
    }
  }

  /// Nahrá obrázok do Supabase storage (bucket `news`, folder `inbox`) a vráti
  /// verejnú URL. Obrázok sa zmenší na max. šírku 1200 px a uloží ako JPG.
  Future<String> uploadImage(Uint8List rawBytes) async {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Neplatný obrázok');
    final resized = decoded.width > 1200
        ? img.copyResize(decoded, width: 1200)
        : decoded;
    final jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 80));

    final userId = _supabase.auth.currentUser?.id ?? 'admin';
    final path =
        'inbox/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage.from('news').uploadBinary(
          path,
          jpg,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return _supabase.storage.from('news').getPublicUrl(path);
  }
}
