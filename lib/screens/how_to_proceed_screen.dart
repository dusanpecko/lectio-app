import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'lectio_screen.dart';

// ----------------------------

class HowToProceedScreen extends StatelessWidget {
  const HowToProceedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text('how.title'.tr(), style: theme.appBarTheme.titleTextStyle),
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/lectio_header.png',
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 16),

                _IntroCard(child: LocalizedRichText(text: "how.intro".tr())),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.lectio.title".tr()),
                      LocalizedRichText(text: "how.lectio.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.meditatio.title".tr()),
                      LocalizedRichText(text: "how.meditatio.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.oratio.title".tr()),
                      LocalizedRichText(text: "how.oratio.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.contemplatio.title".tr()),
                      LocalizedRichText(text: "how.contemplatio.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.actio.title".tr()),
                      LocalizedRichText(text: "how.actio.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.practical.title".tr()),
                      LocalizedRichText(text: "how.practical.body".tr()),
                    ],
                  ),
                ),
                _IntroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headline(context, "how.tips.title".tr()),
                      LocalizedRichText(text: "how.tips.body".tr()),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _IntroCard(
                  child: Center(
                    child: LocalizedRichText(
                      text: "how.wish".tr(),
                      baseStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const LectioScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book),
                    label: Text(
                      'how.button'.tr(),
                      style: theme.elevatedButtonTheme.style?.textStyle
                          ?.resolve({}),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          theme.elevatedButtonTheme.style?.backgroundColor
                              ?.resolve({}) ??
                          theme.primaryColor,
                      foregroundColor:
                          theme.elevatedButtonTheme.style?.foregroundColor
                              ?.resolve({}) ??
                          Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget na headline ---
  static Widget _headline(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// Card widget s paddingom a rounded rohom, s témou
class _IntroCard extends StatelessWidget {
  final Widget child;
  const _IntroCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: theme.cardTheme.elevation ?? 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          theme.cardTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: child,
      ),
    );
  }
}

// =====================
// RICH TEXT PARSER WIDGET
// =====================
class LocalizedRichText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final TextAlign? textAlign;

  const LocalizedRichText({
    required this.text,
    this.baseStyle,
    this.textAlign,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle defaultBaseStyle =
        baseStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.5,
          color: theme.textTheme.bodyMedium?.color ?? Colors.black54,
        ) ??
        const TextStyle(fontSize: 15, height: 1.5);

    final RegExp tagExp = RegExp(
      r'(<b>.*?<\/b>)|(<i>.*?<\/i>)|(<u>.*?<\/u>)|(<color=#(?:[0-9a-fA-F]{6})>.*?<\/color>)',
      caseSensitive: false,
    );
    final List<InlineSpan> spans = [];
    int start = 0;
    final matches = tagExp.allMatches(text);

    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: defaultBaseStyle,
          ),
        );
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('<b>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?b>'), ''),
            style: defaultBaseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
        );
      } else if (matchText.startsWith('<i>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?i>'), ''),
            style: defaultBaseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchText.startsWith('<u>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?u>'), ''),
            style: defaultBaseStyle.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else if (matchText.startsWith('<color=')) {
        final colorMatch = RegExp(
          r'<color=#([0-9a-fA-F]{6})>',
        ).firstMatch(matchText);
        final hexColor = colorMatch?.group(1) ?? '000000';
        final textInside = matchText.replaceAll(
          RegExp(r'<color=#(?:[0-9a-fA-F]{6})>|<\/color>'),
          '',
        );
        spans.add(
          TextSpan(
            text: textInside,
            style: defaultBaseStyle.copyWith(
              color: Color(int.parse('0xFF$hexColor')),
            ),
          ),
        );
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultBaseStyle));
    }

    return RichText(
      text: TextSpan(children: spans, style: defaultBaseStyle),
      textAlign: textAlign ?? TextAlign.start,
    );
  }
}
