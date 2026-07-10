import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/lectio_admin_service.dart';
import '../../services/media_player_bus.dart';
import '../../shared/app_spacing.dart';
import '../home_v2/home_v2_tokens.dart';

/// Karta jedného kroku Lectio (Biblia/Lectio/Meditatio/…) — nadpis, voliteľná
/// referencia, text a vpravo play/pause s kruhovým priebehom prehrávania.
class LectioStepCard extends StatelessWidget {
  /// Unikátny kľúč kroku pre prehrávač (napr. `lectio_audio`).
  final String stepKey;
  final String title;
  final String text;
  final String? reference;
  final String? audioUrl;

  /// Pre Umami audio_heartbeat — id obsahu (dátum lekcie) a jazyk.
  final String? analyticsId;
  final String? language;

  /// Admin in-app editácia (len pre 5 lectio krokov). Aktívne keď [isAdmin]
  /// a [sourceId]+[stepField] sú dostupné.
  final bool isAdmin;
  final int? sourceId;

  /// Krok pre TTS endpoint (`lectio`/`meditatio`/…).
  final String? stepField;

  /// DB stĺpec s textom (`lectio_text`/…) pre uloženie úpravy.
  final String? textField;
  final void Function(String newText)? onTextSaved;
  final void Function(String newUrl)? onAudioRegenerated;

  /// Otvorí fullscreen čítací režim (ak je nastavené) — ikonkou v hlavičke aj
  /// ťuknutím na text.
  final VoidCallback? onExpand;

  const LectioStepCard({
    super.key,
    required this.stepKey,
    required this.title,
    required this.text,
    this.reference,
    this.audioUrl,
    this.analyticsId,
    this.language,
    this.isAdmin = false,
    this.sourceId,
    this.stepField,
    this.textField,
    this.onTextSaved,
    this.onAudioRegenerated,
    this.onExpand,
  });

  bool get _canAdmin =>
      isAdmin && sourceId != null && stepField != null && textField != null;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixná hlavička: názov + referencia + play
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: HomeV2.iconAccent(context),
                      ),
                    ),
                    if (reference != null && reference!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reference!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onExpand != null) ...[
                _ExpandButton(onTap: onExpand!),
                const SizedBox(width: AppSpacing.sm),
              ],
              _CopyButton(text: text),
              if (audioUrl != null && audioUrl!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                StepPlayButton(
                  stepKey: stepKey,
                  url: audioUrl!,
                  title: title,
                  analyticsId: analyticsId,
                  language: language,
                ),
              ],
              if (_canAdmin) ...[
                const SizedBox(width: AppSpacing.sm),
                AdminStepControls(
                  sourceId: sourceId!,
                  stepField: stepField!,
                  textField: textField!,
                  currentText: text,
                  title: title,
                  onTextSaved: onTextSaved,
                  onAudioRegenerated: onAudioRegenerated,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Scrollovateľný text — vyplní zvyšok slidu. Ťuknutie naň otvorí
          // fullscreen čítací režim (ak je dostupný).
          Expanded(
            child: SingleChildScrollView(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onExpand,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okrúhle tlačidlo na skopírovanie textu kroku do schránky.
class _CopyButton extends StatelessWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final accent = HomeV2.iconAccent(context);
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeV2.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            duration: const Duration(seconds: 2),
            content: Text('copied_to_clipboard'.tr()),
          ),
        );
      },
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.copy_rounded, color: accent, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Okrúhle tlačidlo na otvorenie fullscreen čítacieho režimu.
class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = HomeV2.iconAccent(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.open_in_full_rounded, color: accent, size: 18),
          ),
        ),
      ),
    );
  }
}

/// Admin ovládanie kroku: upraviť text + pregenerovať audio (len pre adminov).
/// Verejné — používa ho karta aj fullscreen čítačka.
class AdminStepControls extends StatefulWidget {
  final int sourceId;
  final String stepField;
  final String textField;
  final String currentText;
  final String title;
  final void Function(String newText)? onTextSaved;
  final void Function(String newUrl)? onAudioRegenerated;

  const AdminStepControls({
    super.key,
    required this.sourceId,
    required this.stepField,
    required this.textField,
    required this.currentText,
    required this.title,
    this.onTextSaved,
    this.onAudioRegenerated,
  });

  @override
  State<AdminStepControls> createState() => _AdminStepControlsState();
}

class _AdminStepControlsState extends State<AdminStepControls> {
  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade600 : HomeV2.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        content: Text(msg),
      ),
    );
  }

  Future<void> _showMenu() async {
    HapticFeedback.lightImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeV2.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeV2.textMuted(ctx).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: HomeV2.primary),
              title: const Text('Upraviť text'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.graphic_eq_rounded, color: HomeV2.primary),
              title: const Text('Pregenerovať audio'),
              subtitle: const Text('Vytvorí nové TTS pre tento krok'),
              onTap: () => Navigator.pop(ctx, 'audio'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _openEditor();
    } else if (action == 'audio') {
      await _regenerate();
    }
  }

  Future<void> _openEditor() async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeV2.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StepEditorSheet(
        initial: widget.currentText,
        sourceId: widget.sourceId,
        textField: widget.textField,
        title: widget.title,
      ),
    );
    if (saved != null) {
      widget.onTextSaved?.call(saved);
      _snack('Text uložený');
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pregenerovať audio?'),
        content: Text(
          'Vytvorí sa nová TTS nahrávka pre krok „${widget.title}" '
          'z aktuálneho textu a nahradí pôvodnú.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generovať'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Blokujúci progres počas generovania (ElevenLabs trvá pár sekúnd).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final url = await LectioAdminService.instance.regenerateStepAudio(
        widget.sourceId,
        widget.stepField,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close progress
      }
      widget.onAudioRegenerated?.call(url);
      _snack('Audio pregenerované');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint('❌ regenerate audio failed: $e');
      _snack('Generovanie zlyhalo: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showMenu,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomeV2.gold.withValues(alpha: 0.18),
            ),
            child: Icon(Icons.tune_rounded, color: HomeV2.gold, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet editor textu kroku. Po uložení vráti nový text (alebo null).
class _StepEditorSheet extends StatefulWidget {
  final String initial;
  final int sourceId;
  final String textField;
  final String title;

  const _StepEditorSheet({
    required this.initial,
    required this.sourceId,
    required this.textField,
    required this.title,
  });

  @override
  State<_StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<_StepEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await LectioAdminService.instance.updateStepText(
        widget.sourceId,
        widget.textField,
        _controller.text,
      );
      if (mounted) Navigator.pop(context, _controller.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          content: const Text('Uloženie zlyhalo'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Upraviť: ${widget.title}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: HomeV2.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            maxLines: 12,
            minLines: 6,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: HomeV2.textDark(context),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: HomeV2.background(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: HomeV2.primary,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _saving ? 'Ukladám…' : 'Uložiť',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okrúhle play/pause tlačidlo s kruhovým priebehom prehrávania okolo ikony.
/// Verejné — používa ho karta aj fullscreen čítačka.
class StepPlayButton extends StatelessWidget {
  final String stepKey;
  final String url;
  final String title;
  final String? analyticsId;
  final String? language;

  const StepPlayButton({
    super.key,
    required this.stepKey,
    required this.url,
    required this.title,
    this.analyticsId,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    final controller = MediaPlayerBus.instance;
    final accent = HomeV2.iconAccent(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isCurrent = controller.isCurrent(stepKey);
        return StreamBuilder<bool>(
          stream: controller.playingStream,
          initialData: controller.isPlaying,
          builder: (context, playSnap) {
            return StreamBuilder<ProcessingState>(
              stream: controller.processingStateStream,
              builder: (context, procSnap) {
                final isCompleted =
                    isCurrent && procSnap.data == ProcessingState.completed;
                final isPlaying =
                    isCurrent && (playSnap.data ?? false) && !isCompleted;
                return StreamBuilder<Duration>(
                  stream: controller.positionStream,
                  initialData: controller.position,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: controller.durationStream,
                      initialData: controller.duration,
                      builder: (context, durSnap) {
                        final total = isCurrent ? durSnap.data : null;
                        final pos = isCurrent
                            ? (posSnap.data ?? Duration.zero)
                            : Duration.zero;
                        final progress = isCompleted
                            ? 0.0
                            : (total != null && total.inMilliseconds > 0)
                            ? (pos.inMilliseconds / total.inMilliseconds).clamp(
                                0.0,
                                1.0,
                              )
                            : 0.0;

                        return Semantics(
                          button: true,
                          // Čítačka: „Prehrať/Pozastaviť <krok>" (napr. Lectio).
                          label: '${isPlaying ? 'a11y_pause'.tr() : 'a11y_play'.tr()} — $title',
                          child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.toggle(
                              id: stepKey,
                              url: url,
                              title: title,
                              contentType: 'lectio',
                              contentId: analyticsId,
                              language: language,
                            );
                          },
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: CircularProgressIndicator(
                                    value: isCurrent ? progress : 0.0,
                                    strokeWidth: 3,
                                    backgroundColor: accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    valueColor: AlwaysStoppedAnimation(accent),
                                  ),
                                ),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withValues(alpha: 0.12),
                                  ),
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: accent,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
