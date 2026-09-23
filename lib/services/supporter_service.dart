import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Stav podpory prihláseného používateľa.
class SupporterStatus {
  final String? tier; // friend, friend_plus, patron_mini, patron_plus, patron, founder
  final DateTime? validUntil;
  const SupporterStatus({this.tier, this.validUntil});
  bool get isActive => tier != null;
  static const none = SupporterStatus();
}

/// Jediný zdroj pravdy „je podporovateľ?“ v appke (11.2.4).
///
/// Prečo: dovtedy sa to počítalo na troch miestach a inak — výzva na podporu
/// nekontrolovala `current_period_end`, takže prepadnuté predplatné prešlo ako
/// aktívne. Pravidlo je rovnaké ako na serveri (`activeSupporterTier`):
/// `status = 'active'` A `current_period_end >= now()`. Zahŕňa aj ručne
/// priznané programy z admina (`payment_provider = 'manual'`).
///
/// Cache v pamäti (10 min, per používateľ); `invalidate()` po prihlásení,
/// odhlásení alebo platbe. Bránka pre bonusy sa vždy overuje aj server-side —
/// klient je len pohodlie pre UI (dátumové okno, offline dni, výzvy).
class SupporterService {
  SupporterService._();
  static final SupporterService instance = SupporterService._();

  static const supporterTiers = <String>[
    'friend',
    'friend_plus',
    'patron_mini',
    'patron_plus',
    'patron',
    'founder',
  ];
  static const _ttl = Duration(minutes: 10);

  SupporterStatus? _cached;
  DateTime? _cachedAt;
  String? _cachedUserId;
  bool _authHooked = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Posledný známy stav bez sieťového volania (null = ešte nenačítané).
  SupporterStatus? get cached => _cached;

  Future<bool> isActiveSupporter({bool force = false}) async =>
      (await status(force: force)).isActive;

  Future<SupporterStatus> status({bool force = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _set(SupporterStatus.none, null);
      return SupporterStatus.none;
    }
    final fresh = _cached != null &&
        _cachedUserId == user.id &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl;
    if (fresh && !force) return _cached!;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _supabase
          .from('subscriptions')
          .select('tier, status, current_period_end')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .gte('current_period_end', nowIso)
          .order('current_period_end', ascending: false);
      SupporterStatus result = SupporterStatus.none;
      for (final row in rows as List) {
        final tier = (row['tier'] as String?)?.toLowerCase();
        if (tier == null || !supporterTiers.contains(tier)) continue;
        final until = DateTime.tryParse(row['current_period_end']?.toString() ?? '');
        result = SupporterStatus(tier: tier, validUntil: until);
        break;
      }
      _set(result, user.id);
      return result;
    } catch (e) {
      appLogger.d('Supporter: status load skipped: $e');
      // Pri chybe siete ponechaj posledný známy stav (ak je pre toho istého usera).
      if (_cached != null && _cachedUserId == user.id) return _cached!;
      return SupporterStatus.none;
    }
  }

  void invalidate() {
    _cached = null;
    _cachedAt = null;
    _cachedUserId = null;
  }

  /// Prihlásenie / odhlásenie = nový používateľ = zabudni cache.
  void hookAuthChanges() {
    if (_authHooked) return;
    _authHooked = true;
    _supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userUpdated) {
        invalidate();
      }
    });
  }

  void _set(SupporterStatus s, String? userId) {
    _cached = s;
    _cachedAt = DateTime.now();
    _cachedUserId = userId;
  }
}
