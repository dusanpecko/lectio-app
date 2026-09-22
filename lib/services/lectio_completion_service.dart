import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'app_engagement_service.dart';
import 'media_player_bus.dart';
import 'notification_prompt_service.dart';

/// Jediný vstupný bod pre „používateľ dokončil lectio“ (11.2.4).
///
/// Zdroje: posledný krok Actio v obrazovke lectia, posledný krok čítačky,
/// dohrané kombinované audio lectia kdekoľvek v appke (karta na Home, mini
/// prehrávač, pozadie — vtedy po návrate do popredia).
///
/// Poradie výziev — najviac JEDNA na jedno dokončenie:
///   1. ranná pripomienka (NotificationPromptService) — frekvencia je priorita,
///   2. hodnotenie / kontextová podpora (AppEngagementService) — až po
///      7 rôznych dňoch používania.
class LectioCompletionService {
  LectioCompletionService._();
  static final LectioCompletionService instance = LectioCompletionService._();

  StreamSubscription? _playerSub;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _pendingAfterResume = false;
  bool _busy = false;

  Future<void> onLectioFinished(BuildContext context) async {
    if (_busy) return;
    _busy = true;
    try {
      final shown =
          await NotificationPromptService.instance.onLectioFinished(context);
      if (shown || !context.mounted) return;
      await AppEngagementService.instance.onLectioFinished(context);
    } finally {
      _busy = false;
    }
  }

  /// Globálne sledovanie prehrávača: dohrané kombinované audio lectia
  /// KDEKOĽVEK v appke = dokončené lectio (Dušan 22. 9.: „keď si pustí lectio
  /// na Home a dohrá?“).
  void hookPlayer(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _playerSub ??= MediaPlayerBus.instance.playerStateStream.listen((st) {
      if (st.processingState != ProcessingState.completed) return;
      if (!(MediaPlayerBus.instance.currentId ?? '').startsWith('lectio_audio_')) {
        return;
      }
      _fireFromPlayer();
    });
  }

  /// Z main.dart pri návrate do popredia — ak audio dohralo na pozadí
  /// (zamknutá obrazovka, iná appka), výzva sa ukáže až teraz.
  void onAppResumed() {
    if (!_pendingAfterResume) return;
    _pendingAfterResume = false;
    Future.delayed(const Duration(milliseconds: 800), _fireFromPlayer);
  }

  void _fireFromPlayer() {
    final ctx = _navigatorKey?.currentContext;
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (ctx == null || !inForeground) {
      _pendingAfterResume = true;
      return;
    }
    onLectioFinished(ctx);
  }
}
