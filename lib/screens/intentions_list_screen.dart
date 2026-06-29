//lib/screens/intentions_list_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'intention_submit_screen.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class IntentionsListScreen extends StatefulWidget {
  const IntentionsListScreen({super.key});

  @override
  State<IntentionsListScreen> createState() => _IntentionsListScreenState();
}

class _IntentionsListScreenState extends State<IntentionsListScreen> {
  List<Map<String, dynamic>> intentions = [];
  bool isLoading = false;
  String? role;

  // Cache pre performance optimalizáciu
  Map<int, int> prayerCounts = {};
  Set<int> prayedIntentions = {};
  String? currentUserId;

  static const Color _danger = Color(0xFFC0392B);
  static const Color _success = Color(0xFF2E9E5B);

  @override
  void initState() {
    super.initState();
    fetchRoleAndIntentions();
  }

  void _snack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  Future<void> fetchRoleAndIntentions() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      currentUserId = user.id;

      final userData = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      role = userData?['role'] as String?;

      // Optimalizovaný dopyt s JOIN pre načítanie prayer dát naraz
      List<Map<String, dynamic>> res;
      if (role == 'admin') {
        res = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('intentions')
              .select('''
                *,
                intention_prayers(user_id)
              ''')
              .order('created_at', ascending: false),
        );
      } else {
        // Bežný používateľ vidí: schválené verejné + svoje vlastné (aj neschválené)
        res = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('intentions')
              .select('''
                *,
                intention_prayers(user_id)
              ''')
              .or(
                'and(is_public.eq.true,approved.eq.true),user_id.eq.$currentUserId',
              )
              .order('created_at', ascending: false),
        );
      }

      // Vypočítanie cache pre performance
      _updatePrayerCache(res);

      if (mounted) {
        setState(() {
          intentions = res;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_loading_intentions'.tr()),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            ),
            margin: const EdgeInsets.all(AppSpacing.lg),
            action: SnackBarAction(
              label: 'retry'.tr(),
              textColor: Colors.white,
              onPressed: fetchRoleAndIntentions,
            ),
          ),
        );
      }
    }
  }

  void _updatePrayerCache(List<Map<String, dynamic>> intentionsList) {
    prayerCounts.clear();
    prayedIntentions.clear();

    for (final intention in intentionsList) {
      final intentionId = intention['id'] as int;
      final prayers = intention['intention_prayers'] as List<dynamic>? ?? [];

      // Počet modlitieb
      prayerCounts[intentionId] = prayers.length;

      // Či už používateľ sa modlil
      final userPrayed = prayers.any(
        (prayer) => prayer['user_id'] == currentUserId,
      );
      if (userPrayed) {
        prayedIntentions.add(intentionId);
      }
    }
  }

  Future<void> approveIntention(int id, bool approved) async {
    if (!mounted) return;

    try {
      await Supabase.instance.client
          .from('intentions')
          .update({'approved': approved})
          .eq('id', id);

      if (mounted) {
        fetchRoleAndIntentions();
        _snack(
          approved ? 'intention_approved'.tr() : 'intention_rejected'.tr(),
          isError: false,
        );
      }
    } catch (e) {
      _snack('error_updating_intention'.tr(), isError: true);
    }
  }

  Future<void> onPrayed(int intentionId) async {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    // Optimistic update - okamžite aktualizujeme UI
    setState(() {
      prayedIntentions.add(intentionId);
      prayerCounts[intentionId] = (prayerCounts[intentionId] ?? 0) + 1;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final existing = await Supabase.instance.client
          .from('intention_prayers')
          .select()
          .eq('user_id', user.id)
          .eq('intention_id', intentionId)
          .maybeSingle();

      if (existing == null) {
        await Supabase.instance.client.from('intention_prayers').insert({
          'user_id': user.id,
          'intention_id': intentionId,
        });

        _snack('prayer_recorded'.tr(), isError: false);
      } else {
        // Ak už existuje, vrátíme optimistic update
        if (mounted) {
          setState(() {
            prayedIntentions.remove(intentionId);
            prayerCounts[intentionId] = (prayerCounts[intentionId] ?? 1) - 1;
          });
        }
      }
    } catch (e) {
      // Pri chybe vrátíme optimistic update
      if (mounted) {
        setState(() {
          prayedIntentions.remove(intentionId);
          prayerCounts[intentionId] = (prayerCounts[intentionId] ?? 1) - 1;
        });
        _snack('error_recording_prayer'.tr(), isError: true);
      }
    }
  }

  Future<void> deleteIntention(int intentionId) async {
    if (!mounted) return;

    try {
      await Supabase.instance.client
          .from('intentions')
          .delete()
          .eq('id', intentionId);

      if (mounted) {
        fetchRoleAndIntentions();
        _snack('intention_deleted'.tr(), isError: false);
      }
    } catch (e) {
      _snack('error_deleting_intention'.tr(), isError: true);
    }
  }

  Future<void> _openSubmit({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IntentionSubmitScreen(existingIntention: existing),
      ),
    );
    if (result == true) fetchRoleAndIntentions();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchRoleAndIntentions,
                color: HomeV2.primary,
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHero(),
                    _buildIntroCard(),
                    const SizedBox(height: AppSpacing.lg),
                    if (intentions.isEmpty)
                      _buildEmptyState()
                    else
                      ...intentions.map(_buildDismissibleCard),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 96,
                    ),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openSubmit(),
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'add_intention'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context))
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              const Spacer(),
              _CircleButton(
                icon: Icons.refresh_rounded,
                onTap: fetchRoleAndIntentions,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'intentions_title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Úvodná karta s obrázkom ─────────────────────────────────────────────────
  Widget _buildIntroCard() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/images/modlitba.jpg',
            fit: BoxFit.cover,
            height: isTablet ? 260 : 170,
            errorBuilder: (_, _, _) => ColoredBox(
              color: HomeV2.primary.withValues(alpha: 0.12),
              child: const SizedBox(height: 170),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'intention_intro'.tr(),
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: HomeV2.textDark(context),
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volunteer_activism_outlined,
              size: 52,
              color: HomeV2.iconAccent(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'no_intentions'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Karta úmyslu ────────────────────────────────────────────────────────────
  Widget _buildDismissibleCard(Map<String, dynamic> item) {
    final isAuthor =
        Supabase.instance.client.auth.currentUser?.id == item['user_id'];
    final canDelete = role == 'admin' || isAuthor;
    final card = _buildIntentionCard(item, isAuthor);
    if (!canDelete) return card;

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _danger,
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => deleteIntention(item['id']),
      child: card,
    );
  }

  Future<void> _promptDelete(int id) async {
    final ok = await _confirmDelete();
    if (ok == true) await deleteIntention(id);
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('delete_intention'.tr())),
          ],
        ),
        content: Text('delete_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: HomeV2.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionCard(Map<String, dynamic> item, bool isAuthor) {
    final intentionId = item['id'] as int;
    final prayerCount = prayerCounts[intentionId] ?? 0;
    final alreadyPrayed = prayedIntentions.contains(intentionId);
    final name = item['name']?.toString().trim();
    final hasName = name != null && name.isNotEmpty;
    final isAdmin = role == 'admin';
    final approved = item['approved'] == true;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin || isAuthor)
            Row(
              children: [
                if (isAdmin) _statusBadge(approved),
                const Spacer(),
                if (isAuthor)
                  _miniAction(
                    icon: Icons.edit_outlined,
                    color: HomeV2.iconAccent(context),
                    tooltip: 'edit'.tr(),
                    onTap: () => _openSubmit(existing: item),
                  ),
                if (isAdmin) ...[
                  _miniAction(
                    icon: Icons.check_rounded,
                    color: _success,
                    tooltip: 'approve'.tr(),
                    onTap: () => approveIntention(item['id'], true),
                  ),
                  _miniAction(
                    icon: Icons.close_rounded,
                    color: _danger,
                    tooltip: 'reject'.tr(),
                    onTap: () => approveIntention(item['id'], false),
                  ),
                ],
                if (isAuthor || isAdmin)
                  _miniAction(
                    icon: Icons.delete_outline_rounded,
                    color: _danger,
                    tooltip: 'delete_intention'.tr(),
                    onTap: () => _promptDelete(item['id'] as int),
                  ),
              ],
            ),
          Text(
            item['intention']?.toString() ?? '',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: HomeV2.textDark(context),
            ),
          ),
          if (hasName) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 15,
                  color: HomeV2.textMuted(context),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'from'.tr(args: [name]),
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: HomeV2.textMuted(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(
              height: 1,
              color: HomeV2.primary.withValues(alpha: 0.08),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: HomeV2.gold,
              ),
              const SizedBox(width: 6),
              Text(
                'prayed_count'.tr(args: [prayerCount.toString()]),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HomeV2.textMuted(context),
                ),
              ),
              const Spacer(),
              _prayButton(alreadyPrayed, item['id'] as int),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool approved) {
    final color = approved ? _success : _danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.verified_rounded : Icons.hourglass_empty_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            approved ? 'approved_yes'.tr() : 'approved_no'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: color.withValues(alpha: 0.10),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _prayButton(bool alreadyPrayed, int intentionId) {
    if (alreadyPrayed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: HomeV2.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 17, color: HomeV2.primary),
            const SizedBox(width: 6),
            Text(
              'i_prayed'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: HomeV2.primary,
              ),
            ),
          ],
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => onPrayed(intentionId),
      icon: const Icon(Icons.volunteer_activism_rounded, size: 17),
      label: Text(
        'i_prayed'.tr(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: HomeV2.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
