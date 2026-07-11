import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/confession_mirror.dart';
import '../services/confession_service.dart';
import '../services/confession_vault_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/confession_privacy_sheet.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'confession_screen.dart';

/// PIN brána Spovedného zrkadla — jediný vstup k šifrovanej príprave.
///
/// · Prvé použitie: vysvetlenie ochrany → nastavenie PIN (2×) → voliteľná
///   biometria → vstup.
/// · Ďalšie použitia: PIN alebo biometria (ak je zapnutá — skúsi sa hneď).
/// · „Zabudol som PIN" = nenávratné zmazanie prípravy (zámerne bez obnovy).
/// Obsah zrkadiel sa načítava na pozadí počas zadávania PIN-u.
class ConfessionGateScreen extends StatefulWidget {
  const ConfessionGateScreen({super.key});

  @override
  State<ConfessionGateScreen> createState() => _ConfessionGateScreenState();
}

enum _GateMode { loading, setup, unlock }

class _ConfessionGateScreenState extends State<ConfessionGateScreen> {
  final _vault = ConfessionVaultService.instance;

  _GateMode _mode = _GateMode.loading;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _enableBioOnSetup = true;

  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Obsah sa načítava paralelne so zadávaním PIN-u.
  Future<List<ConfessionMirror>>? _mirrorsFuture;

  @override
  void initState() {
    super.initState();
    ConfessionVaultService.setSecureScreen(true);
    _mirrorsFuture = ConfessionService.instance.fetchMirrors();
    _init();
  }

  @override
  void dispose() {
    // Ochranu obrazovky vypína až spovedná obrazovka pri svojom dispose;
    // ak používateľ odíde priamo z brány, vypni tu.
    if (_mode != _GateMode.loading) {
      ConfessionVaultService.setSecureScreen(false);
    }
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final setUp = await _vault.isSetUp();
    final bioAvail = await _vault.canUseBiometrics();
    final bioEnabled = await _vault.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _mode = setUp ? _GateMode.unlock : _GateMode.setup;
      _bioAvailable = bioAvail;
      _bioEnabled = bioEnabled;
    });
    // Biometria sa ponúkne hneď (PIN ostáva fallback).
    if (setUp && bioEnabled) _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final ok = await _vault.unlockWithBiometrics(
      'confession.bio_reason'.tr(),
    );
    if (ok && mounted) _enter();
  }

  Future<void> _submitSetup() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _pinConfirmCtrl.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() => _error = 'confession.pin_length'.tr());
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'confession.pin_mismatch'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _vault.setupPin(
      pin,
      enableBiometrics: _bioAvailable && _enableBioOnSetup,
    );
    if (mounted) _enter();
  }

  Future<void> _submitUnlock() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _vault.unlockWithPin(pin);
    if (!mounted) return;
    if (ok) {
      _enter();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = 'confession.pin_wrong'.tr();
        _pinCtrl.clear();
      });
    }
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confession.forgot_title'.tr()),
        content: Text('confession.forgot_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confession.forgot_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _vault.wipeAll();
      if (!mounted) return;
      setState(() {
        _mode = _GateMode.setup;
        _pinCtrl.clear();
        _pinConfirmCtrl.clear();
        _error = null;
        _busy = false;
      });
    }
  }

  /// Po odomknutí: nahradí bránu spovednou obrazovkou (1 zrkadlo → rovno;
  /// viac → výber v spovednej obrazovke cez jazyk/zoznam).
  Future<void> _enter() async {
    final mirrors = await (_mirrorsFuture ?? Future.value(<ConfessionMirror>[]));
    if (!mounted) return;
    if (mirrors.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'confession.no_content'.tr();
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ConfessionScreen(mirrors: mirrors)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = _mode == _GateMode.setup;
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      body: SafeArea(
        child: _mode == _GateMode.loading
            ? const Center(
                child: CircularProgressIndicator(color: HomeV2.primary),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Icon(
                    Icons.lock_rounded,
                    size: 56,
                    color: HomeV2.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'confession.title'.tr(),
                    textAlign: TextAlign.center,
                    style: HomeV2.serifTitle(context, size: 26, height: 1.15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isSetup
                        ? 'confession.setup_intro'.tr()
                        : 'confession.unlock_intro'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: HomeV2.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // PIN pole(ia)
                  _pinField(
                    controller: _pinCtrl,
                    label: isSetup
                        ? 'confession.pin_new'.tr()
                        : 'confession.pin_enter'.tr(),
                    onSubmitted: isSetup ? null : (_) => _submitUnlock(),
                  ),
                  if (isSetup) ...[
                    const SizedBox(height: AppSpacing.md),
                    _pinField(
                      controller: _pinConfirmCtrl,
                      label: 'confession.pin_confirm'.tr(),
                      onSubmitted: (_) => _submitSetup(),
                    ),
                    if (_bioAvailable) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'confession.bio_enable'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: _enableBioOnSetup,
                        activeThumbColor: HomeV2.primary,
                        onChanged: (v) =>
                            setState(() => _enableBioOnSetup = v),
                      ),
                    ],
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeV2.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : (isSetup ? _submitSetup : _submitUnlock),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isSetup
                                  ? 'confession.setup_button'.tr()
                                  : 'confession.unlock_button'.tr(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  if (!isSetup) ...[
                    if (_bioEnabled) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        onPressed: _tryBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text('confession.bio_button'.tr()),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _forgotPin,
                      child: Text(
                        'confession.forgot_button'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  // Vysvetlenie ochrany — ťuknutie otvorí plný prehľad
                  // (buduje dôveru v spovedné tajomstvo).
                  Material(
                    color: HomeV2.card(context),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => showConfessionPrivacySheet(context),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 20,
                              color: HomeV2.gold,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'confession.privacy_note'.tr(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.55,
                                      color: HomeV2.textMuted(context),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'confession.info_button'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: HomeV2.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: HomeV2.textMuted(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, letterSpacing: 12),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: HomeV2.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
