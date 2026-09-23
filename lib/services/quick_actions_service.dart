import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

import '../screens/intention_submit_screen.dart';
import '../screens/lectio_screen.dart';
import 'umami_analytics_service.dart';

/// Rýchle akcie po dlhom stlačení ikony appky (11.2.4) — iOS Quick Actions
/// a Android App Shortcuts cez jeden balík.
///
/// Položky sa nastavujú ZA BEHU, nie staticky v Info.plist: appka má vlastný
/// jazyk nezávislý od systémového, takže názvy musia ísť z prekladov.
/// Ťuknutie vždy najprv otvorí appku a až potom sa vykoná akcia.
class QuickActionsService {
  QuickActionsService._();
  static final QuickActionsService instance = QuickActionsService._();

  static const _typeLectio = 'action_lectio';
  static const _typeAudio = 'action_audio';
  static const _typeIntention = 'action_intention';

  final QuickActions _quickActions = const QuickActions();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _handlerReady = false;
  String? _itemsLang;

  /// Zaregistruje obsluhu (raz za beh) a nastaví položky v jazyku appky.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey, String lang) async {
    _navigatorKey = navigatorKey;
    if (!_handlerReady) {
      _handlerReady = true;
      _quickActions.initialize(_handle);
    }
    await refreshItems(lang);
  }

  /// Po zmene jazyka appky prepíš názvy položiek.
  /// Ikony: Android vektory v res/drawable (drží ich res/raw/keep.xml),
  /// iOS template obrázky v asset katalógu — rovnaké názvy pre obe platformy.
  Future<void> refreshItems(String lang) async {
    if (_itemsLang == lang) return;
    final titles = _titles();
    // Pri prvom builde ešte nemusia byť načítané preklady — `tr()` vtedy vráti
    // samotný kľúč a na ploche by svietilo „quick_actions.lectio“.
    // Vtedy to skúsime znova po prvom vykreslení.
    if (titles.values.any((t) => t.startsWith('quick_actions.'))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => refreshItems(lang));
      return;
    }
    _itemsLang = lang;
    await _quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: _typeLectio,
        localizedTitle: titles[_typeLectio]!,
        icon: 'ic_shortcut_lectio',
      ),
      ShortcutItem(
        type: _typeAudio,
        localizedTitle: titles[_typeAudio]!,
        icon: 'ic_shortcut_audio',
      ),
      ShortcutItem(
        type: _typeIntention,
        localizedTitle: titles[_typeIntention]!,
        icon: 'ic_shortcut_intention',
      ),
    ]);
  }

  Map<String, String> _titles() => {
        _typeLectio: 'quick_actions.lectio'.tr(),
        _typeAudio: 'quick_actions.audio'.tr(),
        _typeIntention: 'quick_actions.intention'.tr(),
      };

  void _handle(String type) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    UmamiAnalyticsService().trackEvent('quick_action', eventData: {'type': type});
    switch (type) {
      case _typeLectio:
        nav.push(MaterialPageRoute(
          builder: (_) => LectioScreen(selectedDate: DateTime.now()),
        ));
        break;
      case _typeAudio:
        // Zámer je jasný („Audio“) → prehraj rovno, bez otázky.
        nav.push(MaterialPageRoute(
          builder: (_) => LectioScreen(
            selectedDate: DateTime.now(),
            autoplay: true,
            askBeforeAutoplay: false,
          ),
        ));
        break;
      case _typeIntention:
        nav.push(MaterialPageRoute(
          builder: (_) => const IntentionSubmitScreen(),
        ));
        break;
    }
  }
}
