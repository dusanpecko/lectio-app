// lib/models/rosary_model.dart

import 'package:flutter/material.dart';

enum RosaryCategory {
  joyful, // radostné -> zmenené na anglické názvy ako v DB
  luminous, // svetelné
  sorrowful, // bolestné
  glorious, // slávnostné
}

class RosaryCategoryInfo {
  final String name;
  final String description;
  final String color;
  final IconData icon;
  final int estimatedMinutes;

  const RosaryCategoryInfo({
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.estimatedMinutes,
  });
}

class RosaryDecade {
  final String id; // Zmenené z int na String pre Supabase UUID
  final RosaryCategory category;
  final int order; // 1-5
  final String lang;
  final bool published;

  // Základné údaje
  final String title; // ruzenec
  final String biblicalText; // biblicky_text
  final String introduction; // uvod
  final String? author; // autor

  // Lectio Divina sekcie (rovnaká štruktúra ako adorácia)
  final String? uvodneModlitby; // uvodne_modlitby
  final String? lectioText;
  final String? commentary; // komentar
  final String? meditatioText;
  final String? oratioHtml;
  final String? contemplatioText;
  final String? actioText;

  // Per-sekcia audio (uvod → … → actio)
  final String? introAudio; // uvod_audio
  final String? uvodneModlitbyAudio; // uvodne_modlitby_audio
  final String? lectioAudio; // lectio_audio
  final String? commentaryAudio; // komentar_audio
  final String? meditatioAudio; // meditatio_audio
  final String? oratioAudio; // oratio_audio
  final String? contemplatioAudio; // contemplatio_audio
  final String? actioAudio; // actio_audio
  // Reálne dĺžky sekcií {base → sekundy} (ffprobe; obchádza chybný iOS odhad).
  final Map<String, double> audioDurations;

  // Média
  final String? illustrationImage; // ilustracny_obrazok
  final String? audioRecording; // audio_nahravka (staré jednostopové audio)

  // Spojené „celé audio" (sekcie + meditačná hudba medzi nimi) + jeho dĺžka.
  final String? fullAudioUrl; // full_audio_url
  final double? fullAudioDuration; // full_audio_duration (ffprobe)

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const RosaryDecade({
    required this.id,
    required this.category,
    required this.order,
    required this.lang,
    required this.published,
    required this.title,
    required this.biblicalText,
    required this.introduction,
    this.author,
    this.uvodneModlitby,
    this.lectioText,
    this.commentary,
    this.meditatioText,
    this.oratioHtml,
    this.contemplatioText,
    this.actioText,
    this.introAudio,
    this.uvodneModlitbyAudio,
    this.lectioAudio,
    this.commentaryAudio,
    this.meditatioAudio,
    this.oratioAudio,
    this.contemplatioAudio,
    this.actioAudio,
    this.audioDurations = const {},
    this.illustrationImage,
    this.audioRecording,
    this.fullAudioUrl,
    this.fullAudioDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RosaryDecade.fromJson(Map<String, dynamic> json) {
    return RosaryDecade(
      id: json['id'].toString(), // Zabezpečíme string conversion
      category: RosaryCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['kategoria'],
      ),
      order: _parseIntSafely(json['poradie']) ?? 1, // Bezpečný parsing
      lang: json['lang']?.toString() ?? 'en',
      published: _parseBoolSafely(json['publikovane']) ?? true,
      title: json['ruzenec']?.toString() ?? '',
      biblicalText: json['biblicky_text']?.toString() ?? '',
      introduction: json['uvod']?.toString() ?? '',
      author: json['autor']?.toString(),
      uvodneModlitby: json['uvodne_modlitby']?.toString(),
      lectioText: json['lectio_text']?.toString(),
      commentary: json['komentar']?.toString(),
      meditatioText: json['meditatio_text']?.toString(),
      oratioHtml: json['oratio_html']?.toString(),
      contemplatioText: json['contemplatio_text']?.toString(),
      actioText: json['actio_text']?.toString(),
      introAudio: json['uvod_audio']?.toString(),
      uvodneModlitbyAudio: json['uvodne_modlitby_audio']?.toString(),
      lectioAudio: json['lectio_audio']?.toString(),
      commentaryAudio: json['komentar_audio']?.toString(),
      meditatioAudio: json['meditatio_audio']?.toString(),
      oratioAudio: json['oratio_audio']?.toString(),
      contemplatioAudio: json['contemplatio_audio']?.toString(),
      actioAudio: json['actio_audio']?.toString(),
      audioDurations: _parseDurations(json['audio_durations']),
      illustrationImage: json['ilustracny_obrazok']?.toString(),
      audioRecording: json['audio_nahravka']?.toString(),
      fullAudioUrl: json['full_audio_url']?.toString(),
      fullAudioDuration: _parseDoubleSafely(json['full_audio_duration']),
      createdAt: _parseDateSafely(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateSafely(json['updated_at']) ?? DateTime.now(),
    );
  }

  // Helper metódy pre bezpečný parsing
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _parseBoolSafely(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (value is int) return value != 0;
    return null;
  }

  static DateTime? _parseDateSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // audio_durations JSONB {base: sekundy} → Map<String,double>
  static Map<String, double> _parseDurations(dynamic value) {
    if (value is Map) {
      final out = <String, double>{};
      value.forEach((k, v) {
        final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
        if (d != null) out[k.toString()] = d;
      });
      return out;
    }
    return const {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kategoria': category.toString().split('.').last,
      'poradie': order,
      'lang': lang,
      'publikovane': published,
      'ruzenec': title,
      'biblicky_text': biblicalText,
      'uvod': introduction,
      'autor': author,
      'lectio_text': lectioText,
      'meditatio_text': meditatioText,
      'oratio_html': oratioHtml,
      'contemplatio_text': contemplatioText,
      'actio_text': actioText,
      'ilustracny_obrazok': illustrationImage,
      'audio_nahravka': audioRecording,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get hasAudio => audioRecording != null && audioRecording!.isNotEmpty;
  bool get hasImage =>
      illustrationImage != null && illustrationImage!.isNotEmpty;

  // Pre audio handler
  List<String> get availableAudioSections {
    List<String> sections = [];
    if (audioRecording != null) sections.add('audio_recording');
    return sections;
  }
}

class RosaryCategoryStats {
  final RosaryCategory category;
  final int totalCount;
  final int withAudio;
  final int withImages;

  const RosaryCategoryStats({
    required this.category,
    required this.totalCount,
    required this.withAudio,
    required this.withImages,
  });
}

class RosaryNavigation {
  final RosaryDecade? previousDecade;
  final RosaryDecade? nextDecade;
  final bool canGoToPrevious;
  final bool canGoToNext;

  const RosaryNavigation({
    this.previousDecade,
    this.nextDecade,
    required this.canGoToPrevious,
    required this.canGoToNext,
  });
}
