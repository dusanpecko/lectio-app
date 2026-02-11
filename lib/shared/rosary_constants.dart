// lib/shared/rosary_constants.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rosary_model.dart';

class RosaryConstants {
  static const int averageDecadeMinutes = 15;
  static const int totalDecadesPerCategory = 5;

  // Farebné schémy pre kategórie - zjednotené s AppColors
  static const Map<RosaryCategory, String> categoryColors = {
    RosaryCategory.joyful: '#4A5085',
    RosaryCategory.luminous: '#4A5085',
    RosaryCategory.sorrowful: '#4A5085',
    RosaryCategory.glorious: '#4A5085',
  };

  // Ikony pre kategórie
  static const Map<RosaryCategory, IconData> categoryIcons = {
    RosaryCategory.joyful: Icons.star_rounded,
    RosaryCategory.luminous: Icons.wb_sunny_rounded,
    RosaryCategory.sorrowful: Icons.add_rounded, // Kríž
    RosaryCategory.glorious: Icons.star_border_rounded, // Koruna
  };

  // Získanie informácií o kategórii
  static RosaryCategoryInfo getCategoryInfo(RosaryCategory category) {
    switch (category) {
      case RosaryCategory.joyful:
        return RosaryCategoryInfo(
          name: tr('rosary_joyful'),
          description: tr('rosary_joyful_desc'),
          color: categoryColors[category]!,
          icon: categoryIcons[category]!,
          estimatedMinutes: averageDecadeMinutes * totalDecadesPerCategory,
        );
      case RosaryCategory.luminous:
        return RosaryCategoryInfo(
          name: tr('rosary_luminous'),
          description: tr('rosary_luminous_desc'),
          color: categoryColors[category]!,
          icon: categoryIcons[category]!,
          estimatedMinutes: averageDecadeMinutes * totalDecadesPerCategory,
        );
      case RosaryCategory.sorrowful:
        return RosaryCategoryInfo(
          name: tr('rosary_sorrowful'),
          description: tr('rosary_sorrowful_desc'),
          color: categoryColors[category]!,
          icon: categoryIcons[category]!,
          estimatedMinutes: averageDecadeMinutes * totalDecadesPerCategory,
        );
      case RosaryCategory.glorious:
        return RosaryCategoryInfo(
          name: tr('rosary_glorious'),
          description: tr('rosary_glorious_desc'),
          color: categoryColors[category]!,
          icon: categoryIcons[category]!,
          estimatedMinutes: averageDecadeMinutes * totalDecadesPerCategory,
        );
    }
  }

  // Konverzia hex farby na Color
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Lectio Divina kroky
  static const List<Map<String, dynamic>> lectioDivinaSteps = [
    {
      'id': 'silencio',
      'title': 'Silencio',
      'subtitle': 'Ticho',
      'description': 'Vnútorné stíšenie pred Bohom',
      'duration': 3,
      'color': '#4A5085',
      'icon': Icons.hearing_rounded,
    },
    {
      'id': 'lectio',
      'title': 'Lectio',
      'subtitle': 'Čítanie',
      'description': 'Pozorné čítanie biblického textu',
      'duration': 3,
      'color': '#4A5085',
      'icon': Icons.menu_book_rounded,
    },
    {
      'id': 'meditatio',
      'title': 'Meditatio',
      'subtitle': 'Rozjímanie',
      'description': 'Hlboké rozjímanie nad obsahom',
      'duration': 5,
      'color': '#4A5085',
      'icon': Icons.psychology_rounded,
    },
    {
      'id': 'oratio',
      'title': 'Oratio',
      'subtitle': 'Modlitba',
      'description': 'Modlitba ruženec s tajomstvom',
      'duration': 5,
      'color': '#4A5085',
      'icon': Icons.favorite_rounded,
    },
    {
      'id': 'contemplatio',
      'title': 'Contemplatio',
      'subtitle': 'Kontemplácia',
      'description': 'Tiché sústredenie na Boha',
      'duration': 5,
      'color': '#4A5085',
      'icon': Icons.visibility_rounded,
    },
    {
      'id': 'actio',
      'title': 'Actio',
      'subtitle': 'Konanie',
      'description': 'Praktické uplatnenie v živote',
      'duration': 2,
      'color': '#4A5085',
      'icon': Icons.directions_run_rounded,
    },
  ];

  // Validácia kategórie - teraz pre anglické názvy
  static bool isValidCategory(String categoryString) {
    return RosaryCategory.values.any(
      (category) => category.toString().split('.').last == categoryString,
    );
  }

  // Validácia čísla desiatka
  static bool isValidDecadeNumber(int number) {
    return number >= 1 && number <= totalDecadesPerCategory;
  }

  // Celkový čas na kategóriu
  static int getTotalCategoryDuration(RosaryCategory category) {
    return averageDecadeMinutes * totalDecadesPerCategory;
  }

  // Formátovanie času
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }
}
