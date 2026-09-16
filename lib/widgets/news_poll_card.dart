import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/umami_analytics_service.dart';
import '../shared/app_spacing.dart';
import '../utils/app_logger.dart';
import 'home_v2/home_v2_tokens.dart';

/// Hlasovanie pod článkom (Novinky). Pravidlá drží server
/// (`/api/news/poll/[id]`): 1 účet = 1 hlas, podporovatelia majú predstih,
/// výsledky podľa `show_results`. Widget len zobrazuje stav a posiela hlas.
class NewsPollCard extends StatefulWidget {
  final String pollId;
  /// Zavolá sa, keď chce hlasovať neprihlásený — obrazovka ukáže výzvu na účet.
  final VoidCallback onLoginRequired;

  const NewsPollCard({
    super.key,
    required this.pollId,
    required this.onLoginRequired,
  });

  @override
  State<NewsPollCard> createState() => _NewsPollCardState();
}

class _NewsPollCardState extends State<NewsPollCard> {
  Map<String, dynamic>? _state;
  String? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  String get _backendUrl =>
      dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

  Map<String, String> _headers({bool json = false}) {
    final session = Supabase.instance.client.auth.currentSession;
    return {
      if (json) 'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_backendUrl/api/news/poll/${widget.pollId}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _state = data;
        _selected = data['my_vote'] as String?;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      appLogger.w('news poll load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = tr('news_poll.load_error');
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final state = _state;
    final option = _selected;
    if (state == null || option == null || _submitting) return;
    if (state['authenticated'] != true) {
      widget.onLoginRequired();
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    try {
      final res = await http
          .post(
            Uri.parse('$_backendUrl/api/news/poll/${widget.pollId}/vote'),
            headers: _headers(json: true),
            body: jsonEncode({'option_id': option}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        widget.onLoginRequired();
        return;
      }
      if (res.statusCode != 200) {
        // 403 = okno zavreté / predstih — načítaj aktuálny stav a ukáž dôvod.
        await _load();
        if (res.statusCode != 403 && mounted) {
          setState(() => _error = tr('news_poll.submit_error'));
        }
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      UmamiAnalyticsService().trackEvent(
        'news_poll_vote',
        eventData: {'poll': widget.pollId, 'option': option},
      );
      if (!mounted) return;
      setState(() {
        _state = data;
        _selected = data['my_vote'] as String?;
        _error = null;
      });
    } catch (e) {
      appLogger.w('news poll vote failed: $e');
      if (mounted) setState(() => _error = tr('news_poll.submit_error'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _pick(dynamic text, String lang) {
    if (text is! Map) return '';
    final m = text.cast<String, dynamic>();
    final v = m[lang] ?? m[lang == 'cs' ? 'cz' : lang] ?? m['sk'] ?? m['en'];
    if (v is String && v.isNotEmpty) return v;
    for (final x in m.values) {
      if (x is String && x.isNotEmpty) return x;
    }
    return '';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return DateFormat.yMMMMd(context.locale.toString()).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: HomeV2.card(context),
      borderRadius: BorderRadius.circular(HomeV2.radius),
      boxShadow: HomeV2.softShadowSm(context),
    );

    if (_loading) {
      return Container(
        height: 120,
        decoration: decoration,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final state = _state;
    if (state == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: decoration,
        child: Text(
          _error ?? tr('news_poll.load_error'),
          style: TextStyle(color: HomeV2.textMuted(context)),
        ),
      );
    }

    final lang = context.locale.languageCode;
    final poll = state['poll'] as Map<String, dynamic>;
    final options = (poll['options'] as List? ?? const [])
        .whereType<Map>()
        .map((o) => o.cast<String, dynamic>())
        .toList();
    final phase = state['phase'] as String? ?? 'open';
    final totals = state['totals'] as Map<String, dynamic>?;
    final showResults = state['results_visible'] == true && totals != null;
    final total = (state['total_votes'] as num?)?.toInt() ?? 0;
    final myVote = state['my_vote'] as String?;
    final canVote = state['can_vote'] == true;
    final authenticated = state['authenticated'] == true;
    final isSupporter = state['is_supporter'] == true;

    String? status;
    if (phase == 'closed') {
      status = tr('news_poll.closed');
    } else if (phase == 'upcoming') {
      status = tr('news_poll.opens_at',
          namedArgs: {'date': _fmtDate(poll['supporters_open_at'] as String?)});
    } else if (phase == 'early') {
      status = isSupporter
          ? tr('news_poll.supporter_early')
          : tr('news_poll.early_for_supporters',
              namedArgs: {'date': _fmtDate(poll['opens_at'] as String?)});
    }

    // Neprihlásený v otvorenom okne: možnosti vidí, po klepnutí na Hlasovať
    // dostane výzvu na účet (rovnaká politika ako like/komentár).
    final interactive =
        (canVote || (!authenticated && (phase == 'open' || phase == 'early'))) &&
            !_submitting;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote_rounded,
                  color: HomeV2.iconAccent(context), size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  (_pick(poll['prefix'], lang).isNotEmpty
                          ? _pick(poll['prefix'], lang)
                          : tr('news_poll.title'))
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: HomeV2.iconAccent(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_pick(poll['title'], lang).isNotEmpty) ...[
            Text(
              _pick(poll['title'], lang),
              style: HomeV2.serifTitle(context, size: 20, height: 1.25),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _pick(poll['question'], lang),
              style: TextStyle(
                fontSize: 15.5,
                height: 1.4,
                color: HomeV2.textDark(context),
              ),
            ),
          ] else
            Text(
              _pick(poll['question'], lang),
              style: HomeV2.serifTitle(context, size: 20, height: 1.25),
            ),
          const SizedBox(height: AppSpacing.md),
          for (final o in options) ...[
            _OptionTile(
              label: _pick(o['label'], lang),
              selected: _selected == o['id'],
              isMine: myVote == o['id'],
              percent: showResults && total > 0
                  ? (((totals[o['id']] as num?)?.toDouble() ?? 0) / total)
                  : null,
              onTap: interactive
                  ? () => setState(() => _selected = o['id'] as String?)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
          if (status != null)
            Text(status,
                style: TextStyle(
                    fontSize: 13.5, color: HomeV2.textMuted(context))),
          if (myVote != null && phase != 'closed')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('news_poll.voted'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: HomeV2.iconAccent(context),
                ),
              ),
            ),
          if (showResults)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('news_poll.votes', namedArgs: {'count': total.toString()}),
                style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
              ),
            )
          else if (myVote != null && poll['show_results'] == 'after_close')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('news_poll.results_later'),
                style: TextStyle(fontSize: 12, color: HomeV2.textMuted(context)),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
            ),
          if (!authenticated && (phase == 'open' || phase == 'early')) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('news_poll.login_required'),
              style: TextStyle(fontSize: 13.5, color: HomeV2.textMuted(context)),
            ),
          ],
          if (phase == 'open' || phase == 'early') ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (!authenticated)
                    ? widget.onLoginRequired
                    : (canVote && _selected != null && _selected != myVote && !_submitting)
                        ? _submit
                        : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        authenticated
                            ? Icons.how_to_vote_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                label: Text(
                  !authenticated
                      ? tr('news_poll.login')
                      : myVote != null
                          ? tr('news_poll.change_vote')
                          : tr('news_poll.vote'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isMine;
  /// 0–1 keď sa majú ukázať výsledky, inak null.
  final double? percent;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.isMine,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = HomeV2.primary;
    final borderColor =
        selected ? accent : HomeV2.textMuted(context).withValues(alpha: 0.35);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
            color: selected ? accent.withValues(alpha: 0.06) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (percent != null)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: percent!.clamp(0, 1),
                      child: Container(color: accent.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                child: Row(
                  children: [
                    Icon(
                      isMine
                          ? Icons.check_circle_rounded
                          : selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                      size: 20,
                      color: (isMine || selected)
                          ? accent
                          : HomeV2.textMuted(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HomeV2.textDark(context),
                        ),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        '${(percent! * 100).round()} %',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
