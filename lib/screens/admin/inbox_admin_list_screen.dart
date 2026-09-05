import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/inbox_admin_service.dart';
import '../../shared/app_spacing.dart';
import '../../widgets/home_v2/home_v2_tokens.dart';
import 'inbox_admin_editor_screen.dart';
import 'inbox_admin_ui.dart';

/// Admin: zoznam in-app popup správ (Inbox). Len pre rolu `admin`. Dizajn v2.
class InboxAdminListScreen extends StatefulWidget {
  const InboxAdminListScreen({super.key});

  @override
  State<InboxAdminListScreen> createState() => _InboxAdminListScreenState();
}

class _InboxAdminListScreenState extends State<InboxAdminListScreen> {
  final _service = InboxAdminService.instance;
  late Future<List<InboxAdminMessage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.list();
  }

  void _reload() => setState(() => _future = _service.list());

  Future<void> _openEditor([String? id]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InboxAdminEditorScreen(messageId: id)),
    );
    if (changed == true) _reload();
  }

  Future<void> _confirmDelete(InboxAdminMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        title: const Text('Zmazať správu?'),
        content: Text('„${m.displayTitle}" sa natrvalo odstráni.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
    if (ok != true || m.id == null) return;
    try {
      await _service.delete(m.id!);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Nová správa'),
        ),
        body: Column(
          children: [
            const InboxHero(
              title: 'Inbox správy',
              subtitle: 'In-app popup správy pre používateľov',
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: HomeV2.primary,
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<InboxAdminMessage>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _stateMessage(
              icon: Icons.error_outline,
              text: 'Nepodarilo sa načítať.',
              onRetry: _reload,
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return _stateMessage(
              icon: Icons.inbox_outlined,
              text: 'Zatiaľ žiadne správy.\nVytvor prvú tlačidlom „Nová správa".',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              MediaQuery.of(context).viewPadding.bottom + 96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _InboxCard(
              m: items[i],
              onTap: () => _openEditor(items[i].id),
              onDelete: () => _confirmDelete(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _stateMessage({
    required IconData icon,
    required String text,
    VoidCallback? onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      children: [
        const SizedBox(height: 80),
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: HomeV2.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: HomeV2.iconAccent(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: HomeV2.textMuted(context), fontSize: 15),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
              label: Text(
                'Skúsiť znova',
                style: TextStyle(
                    color: HomeV2.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InboxCard extends StatelessWidget {
  final InboxAdminMessage m;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _InboxCard(
      {required this.m, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      _frequencyLabel(m.frequency),
      if (m.platforms.isNotEmpty) m.platforms.join('/') else 'všetky platformy',
    ].join(' · ');

    return Material(
      color: HomeV2.card(context),
      borderRadius: BorderRadius.circular(HomeV2.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(HomeV2.radius),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeV2.radius),
            boxShadow: HomeV2.softShadowSm(context),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBadge(status: m.status),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      m.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: HomeV2.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
                onPressed: onDelete,
                tooltip: 'Zmazať',
              ),
              Icon(Icons.chevron_right, color: HomeV2.textMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (Colors.green, 'Aktívna'),
      'archived' => (Colors.grey, 'Archív'),
      _ => (Colors.amber.shade800, 'Koncept'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
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
}

String _frequencyLabel(String f) => switch (f) {
      'until_dismissed' => 'do zavretia',
      'every_open' => 'každé otvorenie',
      _ => 'raz',
    };
