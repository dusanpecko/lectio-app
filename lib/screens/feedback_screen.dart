import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _feedbackType = 'suggestion';
  bool _isSubmitting = false;
  String? _appVersion;

  final supabase = Supabase.instance.client;

  static const List<_FeedbackType> _types = [
    _FeedbackType(
      'suggestion',
      'feedback.type_suggestion',
      Icons.lightbulb_outline_rounded,
      Color(0xFFD9A441),
    ),
    _FeedbackType(
      'bug',
      'feedback.type_bug',
      Icons.bug_report_outlined,
      Color(0xFFC75D5D),
    ),
    _FeedbackType(
      'content',
      'feedback.type_content',
      Icons.text_snippet_outlined,
      Color(0xFF5478BE),
    ),
    _FeedbackType(
      'other',
      'feedback.type_other',
      Icons.more_horiz_rounded,
      Color(0xFF8A8FB0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appLogger.d(
        '📱 Package Info: ${packageInfo.version}+${packageInfo.buildNumber}',
      );
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      appLogger.e('❌ Error loading app version: $e');
      if (mounted) {
        setState(() {
          _appVersion = 'unknown';
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2E9E5B) : const Color(0xFFC0392B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final user = supabase.auth.currentUser;
      final session = supabase.auth.currentSession;

      final backendUrl =
          dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

      appLogger.d('📤 Sending feedback to: $backendUrl/api/feedback');
      appLogger.d('📱 Type: $_feedbackType, Version: $_appVersion');

      final response = await http.post(
        Uri.parse('$backendUrl/api/feedback'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'type': _feedbackType,
          'message': _messageController.text.trim(),
          'user_id': user?.id,
          'user_email': user?.email,
          'app_version': _appVersion,
          'platform': Theme.of(context).platform.name,
          'locale': context.locale.languageCode,
        }),
      );

      appLogger.d('📥 Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSnack('feedback.success'.tr(), success: true);
          Navigator.pop(context);
        }
      } else {
        final errorBody = response.body;
        appLogger.e('❌ Error response: $errorBody');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      appLogger.e('❌ Feedback error: $e');
      if (mounted) {
        _showSnack('feedback.error'.tr(args: [e.toString()]), success: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHero(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  bottomInset + AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('feedback.type_label'.tr()),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        for (var i = 0; i < _types.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _buildTypeChip(_types[i])),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _label('feedback.message_label'.tr()),
                    const SizedBox(height: AppSpacing.md),
                    _buildMessageField(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildVersionNote(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: HomeV2.card(context),
              shape: BoxShape.circle,
              boxShadow: HomeV2.softShadowSm(context),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: HomeV2.iconAccent(context),
              size: 26,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'feedback.header'.tr(),
            style: HomeV2.serifTitle(context, size: 26, height: 1.15),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'feedback.subtitle'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sekcie ──────────────────────────────────────────────────────────────────
  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: HomeV2.iconAccent(context),
        ),
      );

  Widget _buildTypeChip(_FeedbackType type) {
    final selected = _feedbackType == type.value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _feedbackType = type.value);
      },
      child: AnimatedContainer(
        duration: HomeV2.anim,
        curve: HomeV2.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? HomeV2.primary : HomeV2.card(context),
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          border: Border.all(
            color: selected
                ? HomeV2.primary
                : type.accent.withValues(alpha: 0.30),
            width: 1.5,
          ),
          boxShadow: selected ? HomeV2.softShadowSm(context) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              size: 16,
              color: selected ? Colors.white : type.accent,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                type.labelKey.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : HomeV2.textDark(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageField() {
    return TextFormField(
      controller: _messageController,
      maxLines: 6,
      style: TextStyle(fontSize: 15, height: 1.5, color: HomeV2.textDark(context)),
      decoration: InputDecoration(
        hintText: 'feedback.message_hint'.tr(),
        hintStyle: TextStyle(color: HomeV2.textMuted(context), height: 1.5),
        filled: true,
        fillColor: HomeV2.card(context),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(
            color: HomeV2.primary.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(
            color: HomeV2.primary.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(color: HomeV2.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFC0392B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFC0392B), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'feedback.message_required'.tr();
        }
        if (value.trim().length < 10) {
          return 'feedback.message_too_short'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildVersionNote() {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: HomeV2.textMuted(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'feedback.app_version'.tr(args: [_appVersion ?? '…']),
            style: TextStyle(fontSize: 12.5, color: HomeV2.textMuted(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeV2.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSubmitting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.send_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _isSubmitting ? 'feedback.sending'.tr() : 'feedback.submit'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackType {
  final String value;
  final String labelKey;
  final IconData icon;
  final Color accent;
  const _FeedbackType(this.value, this.labelKey, this.icon, this.accent);
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
