import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_download_state.dart';
import '../shared/audio_constants.dart';
import '../utils/app_logger.dart';

/// Služba pre sťahovanie a správu offline audio súborov
///
/// Funkcie:
/// - Sťahovanie MP3 z Supabase storage na lokálny disk
/// - Sledovanie stavu stiahnutia (progress, chyby)
/// - Správa lokálneho úložiska (veľkosť, vyčistenie)
/// - Mapovanie URL → lokálny súbor
class AudioDownloadService extends ChangeNotifier {
  static AudioDownloadService? _instance;
  static AudioDownloadService get instance =>
      _instance ??= AudioDownloadService._internal();

  AudioDownloadService._internal();

  static const String _metaKey = 'audio_downloads_meta';
  static const String _audioSubdir = 'offline_audio';

  /// Mapa URL → stav stiahnutia (in-memory)
  final Map<String, AudioDownloadState> _downloads = {};

  /// Mapa URL → lokálna cesta (persistentná)
  final Map<String, String> _downloadedFiles = {};

  /// Či je služba inicializovaná
  bool _initialized = false;

  /// Celková veľkosť stiahnutých súborov v bajtoch
  int _totalStorageBytes = 0;
  int get totalStorageBytes => _totalStorageBytes;

  /// Formátovaná veľkosť úložiska
  String get formattedStorageSize {
    if (_totalStorageBytes < 1024) return '$_totalStorageBytes B';
    if (_totalStorageBytes < 1024 * 1024) {
      return '${(_totalStorageBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_totalStorageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Počet stiahnutých súborov
  int get downloadedFilesCount => _downloadedFiles.length;

  /// Inicializácia služby - načíta metadáta z SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_metaKey);

      if (metaJson != null) {
        final meta = jsonDecode(metaJson) as Map<String, dynamic>;
        _downloadedFiles.clear();

        for (final entry in meta.entries) {
          final localPath = entry.value as String;
          if (await File(localPath).exists()) {
            _downloadedFiles[entry.key] = localPath;
            _downloads[entry.key] = AudioDownloadState(
              url: entry.key,
              localPath: localPath,
              status: AudioDownloadStatus.downloaded,
              progress: 1.0,
            );
          }
        }
      }

      await _calculateStorageSize();
      _initialized = true;
      appLogger.i(
        '🎵 AudioDownloadService inicializovaný: '
        '${_downloadedFiles.length} súborov, '
        '$formattedStorageSize',
      );
    } catch (e) {
      appLogger.e('❌ Chyba pri inicializácii AudioDownloadService: $e');
      _initialized = true; // Mark as initialized even on error
    }
  }

  /// Stiahne interlude hudbu (short + long)
  Future<void> downloadInterlude() async {
    if (!_initialized) await initialize();

    final shortUrl = AudioConstants.interludeShort;
    final longUrl = AudioConstants.interludeLong;

    // Stiahni krátku interlude
    if (!_downloadedFiles.containsKey(shortUrl)) {
      await downloadAudio(
        shortUrl,
        trackKey: 'interlude_short',
        dateKey: 'shared',
      );
    }

    // Stiahni dlhú interlude
    if (!_downloadedFiles.containsKey(longUrl)) {
      await downloadAudio(
        longUrl,
        trackKey: 'interlude_long',
        dateKey: 'shared',
      );
    }

    appLogger.i('✅ Interlude audio stiahnuté');
  }

  /// Vráti lokálnu cestu pre URL ak je stiahnuté
  String? getLocalPath(String url) {
    return _downloadedFiles[url];
  }

  /// Skontroluje či je audio pre dané URL stiahnuté
  bool isDownloaded(String url) {
    return _downloadedFiles.containsKey(url);
  }

  /// Vráti stav stiahnutia pre URL
  AudioDownloadState getDownloadState(String url) {
    return _downloads[url] ??
        AudioDownloadState(url: url, status: AudioDownloadStatus.notDownloaded);
  }

  /// Stiahne jeden audio súbor
  ///
  /// Returns lokálnu cestu alebo null pri chybe.
  Future<String?> downloadAudio(
    String url, {
    String? dateKey,
    String? trackKey,
    void Function(double progress)? onProgress,
  }) async {
    if (!_initialized) await initialize();

    // Už stiahnuté?
    if (_downloadedFiles.containsKey(url)) {
      final localPath = _downloadedFiles[url]!;
      if (await File(localPath).exists()) {
        appLogger.d('📦 Audio už stiahnuté: $trackKey');
        return localPath;
      }
      // Súbor chýba, zmažeme záznam
      _downloadedFiles.remove(url);
    }

    // Nastavíme stav na downloading
    _downloads[url] = AudioDownloadState(
      url: url,
      status: AudioDownloadStatus.downloading,
      progress: 0.0,
    );
    notifyListeners();

    try {
      final directory = await _getAudioDirectory();
      final fileName = _generateFileName(
        url,
        dateKey: dateKey,
        trackKey: trackKey,
      );
      final filePath = '${directory.path}/$fileName';

      appLogger.d('⬇️ Sťahujem audio: $trackKey → $fileName');

      // Stiahni súbor s progress tracking
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final contentLength = response.contentLength ?? 0;
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;

        if (contentLength > 0) {
          final progress = received / contentLength;
          _downloads[url] = _downloads[url]!.copyWith(progress: progress);
          onProgress?.call(progress);
          // Notify menej často - každých 5%
          if ((progress * 100).round() % 5 == 0) {
            notifyListeners();
          }
        }
      }

      await sink.flush();
      await sink.close();

      // Úspech!
      _downloads[url] = AudioDownloadState(
        url: url,
        localPath: filePath,
        status: AudioDownloadStatus.downloaded,
        progress: 1.0,
      );
      _downloadedFiles[url] = filePath;

      await _saveMeta();
      await _calculateStorageSize();
      notifyListeners();

      appLogger.i('✅ Audio stiahnuté: $trackKey (${_formatBytes(received)})');
      return filePath;
    } catch (e) {
      appLogger.e('❌ Chyba pri sťahovaní audio ($trackKey): $e');

      _downloads[url] = AudioDownloadState(
        url: url,
        status: AudioDownloadStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return null;
    }
  }

  /// Stiahne všetky audio tracky pre dané Lectio dáta
  ///
  /// [lectioData] - raw mapa z DB alebo cache
  /// [date] - dátum pre organizáciu súborov
  /// [selectedBible] - vybraná biblia (pre správny audio key)
  Future<DayDownloadResult> downloadAllForDay({
    required Map<String, dynamic> lectioData,
    required String date,
    required String selectedBible,
    void Function(int current, int total, double overallProgress)? onProgress,
  }) async {
    if (!_initialized) await initialize();

    // Extrahuj všetky audio URL z lectioData
    final audioUrls = _extractAudioUrls(lectioData, selectedBible);

    if (audioUrls.isEmpty) {
      appLogger.w('⚠️ Žiadne audio súbory na stiahnutie pre $date');
      return DayDownloadResult(
        date: date,
        successCount: 0,
        totalCount: 0,
        errors: [],
      );
    }

    int successCount = 0;
    final errors = <String>[];

    for (int i = 0; i < audioUrls.length; i++) {
      final entry = audioUrls[i];
      final trackKey = entry.key;
      final url = entry.value;

      try {
        final result = await downloadAudio(
          url,
          dateKey: date,
          trackKey: trackKey,
          onProgress: (progress) {
            final overallProgress = (i + progress) / audioUrls.length;
            onProgress?.call(i + 1, audioUrls.length, overallProgress);
          },
        );

        if (result != null) {
          successCount++;
        } else {
          errors.add('$trackKey: sťahovanie zlyhalo');
        }
      } catch (e) {
        errors.add('$trackKey: $e');
      }

      onProgress?.call(i + 1, audioUrls.length, (i + 1) / audioUrls.length);
    }

    appLogger.i(
      '✅ Audio pre $date: $successCount/${audioUrls.length} stiahnutých',
    );

    return DayDownloadResult(
      date: date,
      successCount: successCount,
      totalCount: audioUrls.length,
      errors: errors,
    );
  }

  /// Extrahuje všetky audio URL z lectioData
  List<MapEntry<String, String>> _extractAudioUrls(
    Map<String, dynamic> lectioData,
    String selectedBible,
  ) {
    final urls = <MapEntry<String, String>>[];

    // Zoznam audio kľúčov
    final audioKeys = [
      'modlitba_audio',
      'lectio_audio',
      'meditatio_audio',
      'oratio_audio',
      'contemplatio_audio',
      'actio_audio',
    ];

    // Bible audio podľa vybranej biblie
    final bibleNumber = _extractBibleNumber(selectedBible);
    audioKeys.insert(1, 'biblia_${bibleNumber}_audio');

    for (final key in audioKeys) {
      final url = lectioData[key];
      if (url != null && url.toString().isNotEmpty) {
        urls.add(MapEntry(key, url.toString()));
      }
    }

    return urls;
  }

  /// Extrahuje číslo biblie z selectedBible stringu
  String _extractBibleNumber(String selectedBible) {
    if (selectedBible.startsWith('bible_en_')) {
      return selectedBible.replaceAll('bible_en_', '');
    }
    return selectedBible.replaceAll('biblia', '');
  }

  /// Vymaže stiahnuté audio pre konkrétny dátum
  Future<void> deleteAudioForDate(String date) async {
    final keysToRemove = <String>[];

    for (final entry in _downloadedFiles.entries) {
      final localPath = entry.value;
      if (localPath.contains('/$date/') || localPath.contains('_${date}_')) {
        try {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
          keysToRemove.add(entry.key);
        } catch (e) {
          appLogger.e('❌ Chyba pri mazaní súboru: $e');
        }
      }
    }

    for (final key in keysToRemove) {
      _downloadedFiles.remove(key);
      _downloads.remove(key);
    }

    await _saveMeta();
    await _calculateStorageSize();
    notifyListeners();

    appLogger.i('🗑️ Zmazané audio pre $date (${keysToRemove.length} súborov)');
  }

  /// Vymaže všetky stiahnuté audio súbory
  Future<void> clearAllDownloads() async {
    try {
      final directory = await _getAudioDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create(recursive: true);
      }

      _downloadedFiles.clear();
      _downloads.clear();
      _totalStorageBytes = 0;

      await _saveMeta();
      notifyListeners();

      appLogger.i('🗑️ Všetky offline audio súbory vymazané');
    } catch (e) {
      appLogger.e('❌ Chyba pri mazaní audio: $e');
    }
  }

  /// Vyčistí staré stiahnutia (staršie ako N dní)
  Future<int> cleanupOldDownloads({int olderThanDays = 14}) async {
    int deletedCount = 0;
    final keysToRemove = <String>[];

    for (final entry in _downloadedFiles.entries) {
      try {
        final file = File(entry.value);
        if (await file.exists()) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inDays > olderThanDays) {
            await file.delete();
            keysToRemove.add(entry.key);
            deletedCount++;
          }
        } else {
          keysToRemove.add(entry.key);
        }
      } catch (e) {
        appLogger.e('❌ Chyba pri čistení: $e');
      }
    }

    for (final key in keysToRemove) {
      _downloadedFiles.remove(key);
      _downloads.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      await _saveMeta();
      await _calculateStorageSize();
      notifyListeners();
    }

    appLogger.i('🧹 Vyčistených $deletedCount starých audio súborov');
    return deletedCount;
  }

  /// Vráti audio priečinok
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/$_audioSubdir');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Generuje názov súboru z URL
  String _generateFileName(String url, {String? dateKey, String? trackKey}) {
    // Deterministic filename based on URL hash + readable parts
    final uri = Uri.parse(url);
    final originalName = uri.pathSegments.last;

    if (dateKey != null && trackKey != null) {
      // Organized by date: 2026-02-07_lectio_audio.mp3
      final ext = originalName.contains('.')
          ? '.${originalName.split('.').last}'
          : '.mp3';
      return '${dateKey}_$trackKey$ext';
    }

    return originalName;
  }

  /// Uloží metadáta do SharedPreferences
  Future<void> _saveMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_metaKey, jsonEncode(_downloadedFiles));
    } catch (e) {
      appLogger.e('❌ Chyba pri ukladaní metadát: $e');
    }
  }

  /// Vypočíta celkovú veľkosť úložiska
  Future<void> _calculateStorageSize() async {
    int totalSize = 0;
    for (final path in _downloadedFiles.values) {
      try {
        final file = File(path);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (_) {}
    }
    _totalStorageBytes = totalSize;
  }

  /// Formátuje bajty na čitateľný tvar
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Výsledok stiahnutia audio pre jeden deň
class DayDownloadResult {
  final String date;
  final int successCount;
  final int totalCount;
  final List<String> errors;

  DayDownloadResult({
    required this.date,
    required this.successCount,
    required this.totalCount,
    this.errors = const [],
  });

  bool get isComplete => successCount == totalCount && totalCount > 0;
}
