import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// Súhrn profilu pre header — avatar + úroveň podpory.
class ProfileSummary {
  final String? avatarUrl;

  /// Tier aktívneho predplatného (`friend`, `patron`, `founder`…) alebo `null`.
  final String? supportTier;

  const ProfileSummary({this.avatarUrl, this.supportTier});

  bool get isSupporter => supportTier != null;

  static const ProfileSummary empty = ProfileSummary();
}

/// Načíta profilovú fotku a úroveň podpory prihláseného používateľa.
///
/// Avatar = `users.avatar_url` (fallback na `user_metadata.avatar_url` z OAuth).
/// Podpora = najnovšie aktívne `subscriptions` (RLS: `auth.uid() = user_id`).
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<ProfileSummary> fetchProfileSummary() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return ProfileSummary.empty;

    String? avatarUrl = user.userMetadata?['avatar_url'] as String?;
    String? tier;

    try {
      final userRow = await _supabase
          .from('users')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final dbAvatar = userRow?['avatar_url'] as String?;
      if (dbAvatar != null && dbAvatar.isNotEmpty) avatarUrl = dbAvatar;
    } catch (e) {
      appLogger.d('Support: avatar load skipped: $e');
    }

    try {
      // Podporovateľ = aktívne predplatné, ktoré EŠTE neskončilo.
      // Bez kontroly current_period_end by zlatý prstenec ostal aj po vypršaní
      // (napr. zrušené cancel_at_period_end alebo nedobehnutý renewal webhook).
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final sub = await _supabase
          .from('subscriptions')
          .select('tier, status, current_period_end')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .gte('current_period_end', nowIso)
          .order('current_period_end', ascending: false)
          .limit(1)
          .maybeSingle();
      tier = sub?['tier'] as String?;
    } catch (e) {
      appLogger.d('Support: subscription load skipped: $e');
    }

    return ProfileSummary(avatarUrl: avatarUrl, supportTier: tier);
  }
}
