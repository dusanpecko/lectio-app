//lib/screens/intention_submit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import '../utils/app_logger.dart';

class IntentionSubmitScreen extends StatefulWidget {
  final Map<String, dynamic>? existingIntention;

  const IntentionSubmitScreen({super.key, this.existingIntention});

  @override
  State<IntentionSubmitScreen> createState() => _IntentionSubmitScreenState();
}

class _IntentionSubmitScreenState extends State<IntentionSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intentionController = TextEditingController();
  bool isPublic = true;
  bool approved = false;
  bool isLoading = false;
  bool isDeleting = false;
  String? userRole;

  static const Color _danger = Color(0xFFC0392B);

  void _snack(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _danger : const Color(0xFF2E9E5B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          ),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();

    if (widget.existingIntention != null) {
      _nameController.text = widget.existingIntention!['name'] ?? '';
      _intentionController.text = widget.existingIntention!['intention'] ?? '';
      isPublic = widget.existingIntention!['is_public'] ?? true;
      approved = widget.existingIntention!['approved'] ?? false;
    }
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final userData = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            userRole = userData?['role'];
          });
        }
      } catch (e) {
        // Log error but don't show to user as this is not critical
        appLogger.w('Error loading user role', error: e);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _snack(tr('user_not_authenticated'), isError: true);
        return;
      }

      final lang = context.locale.languageCode;
      final data = {
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'intention': _intentionController.text.trim(),
        'is_public': isPublic,
        'approved': approved,
      };

      final intentionId = widget.existingIntention?['id'];

      if (intentionId != null) {
        // Edit — `lang` zámerne nemeníme (zachová jazyk pôvodného odoslania).
        await Supabase.instance.client
            .from('intentions')
            .update(data)
            .eq('id', intentionId);
      } else {
        // Nový úmysel — zachytíme jazyk odosielateľa (pre týždennú notifikáciu).
        await Supabase.instance.client
            .from('intentions')
            .insert({...data, 'lang': lang});
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(tr('submit_error'), isError: true);
      appLogger.e('Error submitting intention', error: e);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeV2.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HomeV2.radius),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(tr('intention_delete_title'))),
          ],
        ),
        content: Text(tr('intention_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: HomeV2.textMuted(ctx)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingIntention != null) {
      setState(() => isDeleting = true);

      try {
        await Supabase.instance.client
            .from('intentions')
            .delete()
            .eq('id', widget.existingIntention!['id']);

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        _snack(tr('delete_error'), isError: true);
        appLogger.e('Error deleting intention', error: e);
      } finally {
        if (mounted) {
          setState(() => isDeleting = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingIntention != null;

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
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHero(isEditing),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card(
                      child: Text(
                        tr('intention_motivation'),
                        style: HomeV2.serifQuote(context, size: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel(
                            Icons.person_outline_rounded,
                            tr('your_name_optional'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: HomeV2.textDark(context)),
                            decoration: _inputDecoration(tr('your_name_optional')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel(
                            Icons.favorite_outline_rounded,
                            tr('intention'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _intentionController,
                            maxLines: 6,
                            minLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              height: 1.45,
                              color: HomeV2.textDark(context),
                            ),
                            decoration: _inputDecoration(tr('intention')),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? tr('intention_required')
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _card(
                      child: Column(
                        children: [
                          _switchTile(
                            icon: Icons.public_rounded,
                            label: tr('publish_intention'),
                            value: isPublic,
                            onChanged: (v) => setState(() => isPublic = v),
                          ),
                          if (userRole == 'admin') ...[
                            Divider(
                              height: AppSpacing.lg,
                              color: HomeV2.primary.withValues(alpha: 0.08),
                            ),
                            _switchTile(
                              icon: Icons.verified_outlined,
                              label: tr('approved'),
                              value: approved,
                              onChanged: (v) => setState(() => approved = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSubmitButton(isEditing),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero(bool isEditing) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
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
          Row(
            children: [
              _CircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (isEditing)
                _CircleButton(
                  icon: Icons.delete_outline_rounded,
                  iconColor: _danger,
                  onTap: isDeleting ? null : _delete,
                  busy: isDeleting,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isEditing ? tr('edit_intention_title') : tr('new_intention_title'),
            style: HomeV2.serifTitle(context, size: 28, height: 1.1),
          ),
        ],
      ),
    );
  }

  // ── Stavebné prvky ──────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: HomeV2.card(context),
        borderRadius: BorderRadius.circular(HomeV2.radius),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      child: child,
    );
  }

  Widget _fieldLabel(IconData icon, String label) {
    final accent = HomeV2.iconAccent(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(HomeV2.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: HomeV2.textMuted(context), fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: HomeV2.isDark(context)
          ? Colors.white.withValues(alpha: 0.04)
          : HomeV2.primary.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      enabledBorder: border(HomeV2.primary.withValues(alpha: 0.15), 1),
      focusedBorder: border(HomeV2.primary, 1.5),
      errorBorder: border(_danger, 1),
      focusedErrorBorder: border(_danger, 1.5),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 19, color: HomeV2.iconAccent(context)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HomeV2.textDark(context),
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: HomeV2.primary,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
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
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(isEditing ? Icons.save_rounded : Icons.send_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isEditing ? tr('save_changes') : tr('submit_intention'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool busy;
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: SizedBox(
          width: 44,
          height: 44,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor ?? HomeV2.primary,
                  ),
                )
              : Icon(icon, color: iconColor ?? HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
