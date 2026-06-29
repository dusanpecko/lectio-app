import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../controllers/notification_controller.dart';
import '../screens/lectio_screen.dart';
import '../utils/app_logger.dart';

/// Most medzi appkou a domovským widgetom „Actio" (iOS WidgetKit + Android
/// AppWidget). Appka zapíše dnešné actio do zdieľaného úložiska a požiada o
/// refresh; po ťuknutí na widget otvorí dnešné Lectio.
class HomeWidgetService {
  HomeWidgetService._();

  /// iOS App Group — musí sa zhodovať s nastavením v Xcode + Apple Developer
  /// portáli. Android ho ignoruje (používa vlastné SharedPreferences).
  static const String _appGroupId = 'group.sk.dpapp.app.ios604688a889d93';

  /// Názov iOS widget structu (`kind`).
  static const String _iOSName = 'ActioWidget';

  /// Plný názov Android provider triedy.
  static const String _qualifiedAndroidName =
      'sk.dpapp.app.android604688a88a394.ActioWidgetProvider';

  /// Host v deep-linku z widgetu (`lectio-divina://actio`).
  static const String _clickHost = 'actio';

  /// Názov route Lectia.
  static const String _lectioRoute = '/lectio';

  static bool _inited = false;
  static AppLinks? _appLinks;

  /// Home je už nasadený ako root → vtedy je bezpečné navigovať na Lectio.
  static bool _homeReady = false;

  /// Žiadosť z widgetu prišla skôr, než bol Home pripravený (cold start).
  static bool _pending = false;

  /// Zavolať raz po štarte (po prvom frame).
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      // Živé ťuknutia počas behu appky. Deep-link `lectio-divina://actio`
      // zachytáva aj home_widget aj app_links (rovnaký scheme ako payment/OAuth)
      // — počúvame OBA, `actio` spracujeme nech ho doručí ktorýkoľvek; iné hosty
      // ignorujeme (rieši ich príslušná obrazovka).
      HomeWidget.widgetClicked.listen(_onUri);
      _appLinks = AppLinks();
      _appLinks!.uriLinkStream.listen(_onUri, onError: (_) {});

      // Studený štart z widgetu — z oboch zdrojov. Nenavigujeme hneď (štart je
      // volatilný, root sa ešte ustaľuje), iba si zapamätáme zámer; otvorí ho
      // HomeScreen cez markHomeReady().
      final fromWidget = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (_isActio(fromWidget)) _requestOpenLectio();
      try {
        final initial = await _appLinks!.getInitialLink();
        if (_isActio(initial)) _requestOpenLectio();
      } catch (_) {
        // best-effort
      }
    } catch (e) {
      appLogger.w('⚠️ HomeWidgetService.init zlyhalo: $e');
    }
  }

  /// Zavolá HomeScreen po prvom frame, keď je nasadený ako root navigatora.
  /// Vtedy spracujeme prípadnú odloženú žiadosť z widgetu (cold start).
  static void markHomeReady() {
    _homeReady = true;
    if (_pending) {
      _pending = false;
      // Krátky settle — nech doznejú prípadné štartové navigácie, potom
      // zásobník čisto zložíme na [Home, Lectio].
      Future.delayed(const Duration(milliseconds: 250), _openLectio);
    }
  }

  /// Zapíše dnešné actio do widgetu a vyžiada refresh.
  static Future<void> pushActio({
    required String? text,
    String? reference,
    required DateTime date,
  }) async {
    final t = text?.trim();
    if (t == null || t.isEmpty) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<String>('actio_text', t);
      await HomeWidget.saveWidgetData<String>('actio_ref', reference ?? '');
      await HomeWidget.saveWidgetData<String>(
        'actio_date',
        date.toIso8601String().substring(0, 10),
      );
      await HomeWidget.updateWidget(
        iOSName: _iOSName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (e) {
      appLogger.w('⚠️ HomeWidgetService.pushActio zlyhalo: $e');
    }
  }

  static bool _isActio(Uri? uri) => uri != null && uri.host == _clickHost;

  static void _onUri(Uri? uri) {
    if (!_isActio(uri)) return;
    _requestOpenLectio();
  }

  /// Otvor Lectio — ak je Home pripravený, hneď; inak odlož na markHomeReady().
  static void _requestOpenLectio() {
    if (!_homeReady) {
      _pending = true;
      return;
    }
    _openLectio();
  }

  /// Zhodí všetko po root a otvorí Lectio → vždy čisté **[Home, Lectio]**, nech
  /// sa pri štarte stalo s navigáciou čokoľvek. Idempotentné (opakované
  /// doručenie linku len znovu nastaví ten istý stav). Ak navigator ešte nie je
  /// nasadený, skúša znova po každom frame.
  static void _openLectio({int attempt = 0}) {
    final nav = NotificationController.instance.navigatorKey.currentState;
    if (nav == null) {
      if (attempt > 60) {
        appLogger.w('⚠️ Widget → Lectio: navigator sa nenasadil, vzdávam to');
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openLectio(attempt: attempt + 1),
      );
      return;
    }
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LectioScreen(selectedDate: DateTime.now()),
        settings: const RouteSettings(name: _lectioRoute),
      ),
      (route) => route.isFirst,
    );
  }
}
