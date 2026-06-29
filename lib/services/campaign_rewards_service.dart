import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campaign_reward.dart';
import '../utils/app_logger.dart';

/// Načítanie odmien za dar pre danú kampaň. Obsah je verejný (RLS public-read
/// aktívnych) — číta sa priamo cez Supabase, ako help_articles.
class CampaignRewardsService {
  CampaignRewardsService._();
  static final CampaignRewardsService instance = CampaignRewardsService._();

  Future<List<CampaignReward>> fetchForCampaign(String campaign) async {
    try {
      final data = await Supabase.instance.client
          .from('campaign_rewards')
          .select('id, campaign, title, description, image_url, amount, sort_order, limit_qty, claimed_count')
          .eq('campaign', campaign)
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => CampaignReward.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Best-effort — bez odmien sa sekcia jednoducho nezobrazí.
      appLogger.w('⚠️ CampaignRewardsService.fetchForCampaign($campaign): $e');
      return [];
    }
  }
}
