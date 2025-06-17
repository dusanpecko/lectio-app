import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'how_to_proceed_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          "intro_pages.title".tr(),
          style: theme.appBarTheme.titleTextStyle,
        ),
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/lectio_header.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                ),
              ),
              const SizedBox(height: 24),
              _IntroCard(text: "intro_pages.section1".tr()),
              const SizedBox(height: 14),
              _IntroCard(text: "intro_pages.section2".tr()),
              const SizedBox(height: 14),
              _IntroCard(text: "intro_pages.section3".tr()),
              const SizedBox(height: 14),
              _IntroCard(text: "intro_pages.section4".tr()),
              const SizedBox(height: 14),
              _IntroCard(text: "intro_pages.section5".tr()),
              const SizedBox(height: 14),
              _IntroCard(text: "intro_pages.section6".tr()),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    "intro_pages.button".tr(),
                    style: theme.elevatedButtonTheme.style?.textStyle?.resolve(
                      {},
                    ),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HowToProceedScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String text;
  const _IntroCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: theme.cardTheme.elevation ?? 2,
      shape:
          theme.cardTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: LocalizedRichText(
          text: text,
          baseStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            height: 1.45,
            color: theme.textTheme.bodyMedium?.color ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Custom parser pre <b>, <i>, <u> a <color=#xxxxxx> tagy v texte
class LocalizedRichText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const LocalizedRichText({required this.text, this.baseStyle, super.key});

  @override
  Widget build(BuildContext context) {
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
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('<b>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?b>'), ''),
            style:
                baseStyle?.copyWith(fontWeight: FontWeight.bold) ??
                const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchText.startsWith('<i>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?i>'), ''),
            style:
                baseStyle?.copyWith(fontStyle: FontStyle.italic) ??
                const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchText.startsWith('<u>')) {
        spans.add(
          TextSpan(
            text: matchText.replaceAll(RegExp(r'<\/?u>'), ''),
            style:
                baseStyle?.copyWith(decoration: TextDecoration.underline) ??
                const TextStyle(decoration: TextDecoration.underline),
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
            style:
                baseStyle?.copyWith(color: Color(int.parse('0xFF$hexColor'))) ??
                TextStyle(color: Color(int.parse('0xFF$hexColor'))),
          ),
        );
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: baseStyle ?? DefaultTextStyle.of(context).style,
      ),
      textAlign: TextAlign.start,
    );
  }
}
