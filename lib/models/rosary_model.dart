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

  // Lectio Divina sekcie
  final String? lectioText;
  final String? meditatioText;
  final String? oratioHtml;
  final String? contemplatioText;
  final String? actioText;

  // Média
  final String? illustrationImage; // ilustracny_obrazok
  final String? audioRecording; // audio_nahravka

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
    this.lectioText,
    this.meditatioText,
    this.oratioHtml,
    this.contemplatioText,
    this.actioText,
    this.illustrationImage,
    this.audioRecording,
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
      lectioText: json['lectio_text']?.toString(),
      meditatioText: json['meditatio_text']?.toString(),
      oratioHtml: json['oratio_html']?.toString(),
      contemplatioText: json['contemplatio_text']?.toString(),
      actioText: json['actio_text']?.toString(),
      illustrationImage: json['ilustracny_obrazok']?.toString(),
      audioRecording: json['audio_nahravka']?.toString(),
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
