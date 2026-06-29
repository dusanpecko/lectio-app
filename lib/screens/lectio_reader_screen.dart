import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../widgets/lectio_v2/lectio_step_card.dart';

/// Jeden krok pre fullscreen čítačku (Biblia/Lectio/Meditatio/…).
class LectioReaderStep {
  final String stepKey;
  final String title;
  final String text;
  final String? reference;
  final String? audioUrl;
  final String? analyticsId;
  final String? language;

  // Admin in-app editácia (rovnaké ako na karte) — len pre 5 lectio krokov.
  final bool isAdmin;
  final int? sourceId;
  final String? stepField;
  final String? textField;
  final void Function(String newText)? onTextSaved;
  final void Function(String newUrl)? onAudioRegenerated;

  const LectioReaderStep({
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
  });

  bool get canAdmin =>
      isAdmin && sourceId != null && stepField != null && textField != null;

  LectioReaderStep copyWith({String? text, String? audioUrl}) =>
      LectioReaderStep(
        stepKey: stepKey,
        title: title,
        text: text ?? this.text,
        reference: reference,
        audioUrl: audioUrl ?? this.audioUrl,
        analyticsId: analyticsId,
        language: language,
        isAdmin: isAdmin,
        sourceId: sourceId,
        stepField: stepField,
        textField: textField,
        onTextSaved: onTextSaved,
        onAudioRegenerated: onAudioRegenerated,
      );
}

/// Fullscreen čítací režim Lectio — text edge-to-edge, swipe medzi krokmi.
/// Otvára sa ťuknutím na kartu kroku v [LectioScreen].
class LectioReaderScreen extends StatefulWidget {
  final List<LectioReaderStep> steps;
  final int initialIndex;

  /// Volá sa pri každom prelistovaní na iný krok — [LectioScreen] tak vie
  /// po zatvorení čítačky zosynchronizovať malý slide na rovnaký krok.
  final ValueChanged<int>? onIndexChanged;

  const LectioReaderScreen({
    super.key,
    required this.steps,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  @override
  State<LectioReaderScreen> createState() => _LectioReaderScreenState();
}

class _LectioReaderScreenState extends State<LectioReaderScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  // Lokálna kópia — admin úpravy sa prejavia hneď aj v čítačke.
  late final List<LectioReaderStep> _steps = List.of(widget.steps);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: Column(
        children: [
          SizedBox(height: topPad + AppSpacing.xs),
          // Horná lišta: zavrieť + počítadlo krokov (i / n).
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: HomeV2.textDark(context),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  '${_index + 1} / ${_steps.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ),
              const SizedBox(width: 48), // symetria k close tlačidlu
            ],
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _steps.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                widget.onIndexChanged?.call(i);
              },
              itemBuilder: (_, i) => _ReaderPage(
                step: _steps[i],
                bottomPad: bottomPad,
                // Admin úprava: prejav lokálne (čítačka) + propaguj do lectio.
                onTextSaved: (t) {
                  _steps[i].onTextSaved?.call(t);
                  setState(() => _steps[i] = _steps[i].copyWith(text: t));
                },
                onAudioRegenerated: (u) {
                  _steps[i].onAudioRegenerated?.call(u);
                  setState(() => _steps[i] = _steps[i].copyWith(audioUrl: u));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderPage extends StatelessWidget {
  final LectioReaderStep step;
  final double bottomPad;
  final void Function(String newText)? onTextSaved;
  final void Function(String newUrl)? onAudioRegenerated;
  const _ReaderPage({
    required this.step,
    required this.bottomPad,
    this.onTextSaved,
    this.onAudioRegenerated,
  });

  @override
  Widget build(BuildContext context) {
    // Roztvorená karta = rovnaký dizajn ako zatvorená (biela karta na pozadí),
    // len na celú obrazovku a s pohodlnejším textom.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        bottomPad + AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radius),
          boxShadow: HomeV2.softShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: HomeV2.iconAccent(context),
                        ),
                      ),
                      if (step.reference != null &&
                          step.reference!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          step.reference!,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: HomeV2.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ReaderCopyButton(text: step.text),
                if (step.audioUrl != null && step.audioUrl!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StepPlayButton(
                    stepKey: step.stepKey,
                    url: step.audioUrl!,
                    title: step.title,
                    analyticsId: step.analyticsId,
                    language: step.language,
                  ),
                ],
                if (step.canAdmin) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AdminStepControls(
                    sourceId: step.sourceId!,
                    stepField: step.stepField!,
                    textField: step.textField!,
                    currentText: step.text,
                    title: step.title,
                    onTextSaved: onTextSaved,
                    onAudioRegenerated: onAudioRegenerated,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Scrollovateľný čítací text — vyplní zvyšok karty.
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  step.text,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.7,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderCopyButton extends StatelessWidget {
  final String text;
  const _ReaderCopyButton({required this.text});

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
            duration: const Duration(seconds: 2),
            content: Text('copied_to_clipboard'.tr()),
          ),
        );
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.copy_rounded, color: accent, size: 18),
          ),
        ),
      ),
    );
  }
}
