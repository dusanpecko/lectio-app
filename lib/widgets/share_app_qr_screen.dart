import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/app_spacing.dart';
import 'home_v2/home_v2_tokens.dart';

/// QR kód na zdieľanie appky z ruky do ruky (11.2.5) — po omši, v
/// spoločenstve, v rodine: človek ukáže mobil, druhý si appku naskenuje.
/// Odkaz má vlastnú značku (`z=app-qr`), aby bolo v `app_link` vidno,
/// koľko ľudí prišlo cez QR v appke oproti odoslanej pozvánke.
Future<void> showShareAppQr(BuildContext context, {required String url}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ShareAppQrScreen(url: url),
    ),
  );
}

class _ShareAppQrScreen extends StatelessWidget {
  const _ShareAppQrScreen({required this.url});
  final String url;

  // QR vždy tmavý na bielom — v tmavom režime by invertovaný kód
  // niektoré fotoaparáty nenačítali.
  static const _qrInk = Color(0xFF0A0E1A);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final qrSize = math.min(width - 2 * AppSpacing.lg - 48, 300.0);

    return Scaffold(
      backgroundColor: HomeV2.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Téma appky dáva AppBaru bielu farbu ikon (pre fialovú lištu) —
        // na priehľadnej lište nad svetlým pozadím by X nebolo vidno.
        foregroundColor: HomeV2.textDark(context),
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 28,
            color: HomeV2.textDark(context),
          ),
          tooltip: 'close'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'share_app.qr_title'.tr(),
                  textAlign: TextAlign.center,
                  style: HomeV2.serifTitle(context, size: 26, height: 1.15),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'share_app.qr_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: HomeV2.textMuted(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(HomeV2.radius),
                    boxShadow: HomeV2.softShadow(context),
                  ),
                  child: Semantics(
                    label: 'share_app.qr_title'.tr(),
                    image: true,
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: qrSize,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: _qrInk,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: _qrInk,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'lectio.one',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HomeV2.iconAccent(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'share_app.qr_platforms'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: HomeV2.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
