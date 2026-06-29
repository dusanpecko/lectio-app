import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

enum AppUpdateType { none, soft, force }

class AppUpdateInfo {
  final AppUpdateType type;
  final String storeUrl;
  const AppUpdateInfo(this.type, this.storeUrl);
}

/// Kontrola verzie appky voči vzdialenému zdroju (`app_versions` v Supabase).
/// Appka pozná len svoju verziu (z kódu) — minimálnu/najnovšiu drží DB, takže
/// sa dá meniť bez nového releasu. Pri chybe/offline **fail-open** (nič nezobrazí).
class AppVersionService {
  AppVersionService._();
  static final AppVersionService instance = AppVersionService._();

  Future<AppUpdateInfo?> check() async {
    try {
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : null;
      if (platform == null) return null;

      final row = await Supabase.instance.client
          .from('app_versions')
          .select('min_version, latest_version, store_url, enabled')
          .eq('platform', platform)
          .maybeSingle();

      if (row == null || row['enabled'] != true) return null;

      final storeUrl = (row['store_url'] as String?)?.trim() ?? '';
      if (storeUrl.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final current = info.version; // napr. "10.2.0"
      final minV = row['min_version'] as String?;
      final latestV = row['latest_version'] as String?;

      if (minV != null && _compare(current, minV) < 0) {
        return AppUpdateInfo(AppUpdateType.force, storeUrl);
      }
      if (latestV != null && _compare(current, latestV) < 0) {
        return AppUpdateInfo(AppUpdateType.soft, storeUrl);
      }
      return const AppUpdateInfo(AppUpdateType.none, '');
    } catch (e) {
      // Fail-open: pri chybe/offline používateľa nikdy nezablokujeme.
      appLogger.w('⚠️ AppVersionService.check zlyhalo (fail-open): $e');
      return null;
    }
  }

  /// Porovná dve verzie ("10.2.0" vs "10.10.0"). Ignoruje build za '+'.
  /// -1 ak a < b, 0 ak rovnaké, 1 ak a > b.
  int _compare(String a, String b) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }
}
