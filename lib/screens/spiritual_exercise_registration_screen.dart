import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/spiritual_exercise.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';

class SpiritualExerciseRegistrationScreen extends StatefulWidget {
  final String exerciseSlug;
  final String exerciseTitle;
  final String? homeImageUrl;
  final List<SpiritualExercisePricing> pricing;

  const SpiritualExerciseRegistrationScreen({
    super.key,
    required this.exerciseSlug,
    required this.exerciseTitle,
    this.homeImageUrl,
    required this.pricing,
  });

  @override
  State<SpiritualExerciseRegistrationScreen> createState() =>
      _SpiritualExerciseRegistrationScreenState();
}

class _SpiritualExerciseRegistrationScreenState
    extends State<SpiritualExerciseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form data
  String _email = '';
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _birthDate = '';
  String _idCardNumber = '';
  String _city = '';
  String _street = '';
  String _postalCode = '';
  String _parish = '';
  String _diocese = '';
  String _roomType = '';
  String _dietaryRestrictions = '';
  String _notes = '';
  String _referralSource = '';
  bool _gdprConsent = false;
  bool _responsibilityConsent = false;
  bool _newsletterConsent = false;
  String _paymentMethod = 'card'; // 'card' (Mollie) | 'bank' (prevod)

  // State
  bool _isSubmitting = false;
  String? _serverError;
  // Backend + deep link návrat z Mollie
  static const String _baseUrl = 'https://www.lectio.one';
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _awaitingCardPayment = false;

  // Constants
  static const List<String> _referralSources = [
    'Z aplikácie Lectio divina',
    'Od známych',
    'Z internetu',
    'Od kňaza',
    'Iné',
  ];

  static const List<String> _slovakDioceses = [
    'Bratislavská',
    'Trnavská',
    'Nitrianská',
    'Banskobystrická',
    'Žilinská',
    'Košická',
    'Rožňavská',
    'Spišská',
    'Gréckokatolícka eparchia Prešov',
    'Gréckokatolícka eparchia Košice',
    'Gréckokatolícka eparchia Bratislava',
    'Iná',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.pricing.isNotEmpty) {
      _roomType = widget.pricing.first.roomType;
    }
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'lectio-divina' &&
          uri.host == 'payment-success' &&
          (uri.queryParameters['type'] ?? '') == 'spiritual_exercise') {
        _onCardPaid();
      }
    });
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Návrat z Mollie po úspešnej platbe kartou (deep link).
  void _onCardPaid() {
    if (!mounted || !_awaitingCardPayment) return;
    _awaitingCardPayment = false;
    setState(() => _isSubmitting = false);
    _showSuccessDialog();
  }

  Future<void> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        final profile = await supabase
            .from('users')
            .select('full_name, email, shipping_address')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          final shippingAddr =
              profile['shipping_address'] as Map<String, dynamic>?;

          setState(() {
            // Parse full name
            final fullName = profile['full_name'] as String?;
            if (fullName != null && fullName.isNotEmpty) {
              final nameParts = fullName.trim().split(' ');
              if (nameParts.length > 1) {
                _firstName = nameParts[0];
                _lastName = nameParts.sublist(1).join(' ');
              } else {
                _firstName = fullName;
              }
            }

            _email = profile['email'] ?? '';

            if (shippingAddr != null) {
              _phone = shippingAddr['phone'] ?? '';
              _street = shippingAddr['street'] ?? '';
              _city = shippingAddr['city'] ?? '';
              _postalCode = shippingAddr['postal_code'] ?? '';
            }
          });
        }
      } catch (e) {
        appLogger.e('❌ Error fetching profile: $e');
      }
    }
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  bool _validatePhone(String phone) {
    final phoneRegex = RegExp(r'^(\+421|0)[0-9]{9}$');
    return phoneRegex.hasMatch(phone.replaceAll(' ', ''));
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_gdprConsent) {
      _showError(tr('registration_gdpr_required'));
      return;
    }

    if (!_responsibilityConsent) {
      _showError(tr('registration_responsibility_required'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('$_baseUrl/api/spiritual-exercises/${widget.exerciseSlug}/register'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': _email,
          'first_name': _firstName,
          'last_name': _lastName,
          'phone': _phone,
          'birth_date': _birthDate,
          'id_card_number': _idCardNumber,
          'city': _city,
          'street': _street,
          'postal_code': _postalCode,
          'parish': _parish,
          'diocese': _diocese,
          'room_type': _roomType,
          'dietary_restrictions': _dietaryRestrictions,
          'notes': _notes,
          'referral_source': _referralSource,
          'gdpr_consent': _gdprConsent,
          'responsibility_consent': _responsibilityConsent,
          'newsletter_consent': _newsletterConsent,
          'payment_method': _paymentMethod,
          'platform': 'mobile',
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['error'] ?? 'Nepodarilo sa odoslať registráciu');
      }

      if (!mounted) return;
      final payment = (data['payment'] as Map?)?.cast<String, dynamic>();

      // Platba kartou → otvor Mollie checkout; po úhrade príde deep link.
      if (_paymentMethod == 'card' && payment?['checkoutUrl'] is String) {
        _awaitingCardPayment = true;
        await launchUrl(
          Uri.parse(payment!['checkoutUrl'] as String),
          mode: LaunchMode.externalApplication,
        );
        return; // _isSubmitting necháme true kým sa nevráti z platby
      }

      // Platba na účet → ukáž bankové údaje (VS, suma).
      setState(() => _isSubmitting = false);
      _showBankDetailsDialog(payment);
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  void _showBankDetailsDialog(Map<String, dynamic>? payment) {
    final amount = payment?['amount'];
    final vs = payment?['variableSymbol']?.toString() ?? '';
    final iban = payment?['iban']?.toString() ?? 'SK42 7500 0000 0040 3515 6222';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: AppColors.primary, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(tr('se_bank_title'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('se_bank_instructions')),
            const SizedBox(height: AppSpacing.md),
            _bankRow(tr('se_bank_account'), iban),
            _bankRow(tr('se_bank_vs'), vs),
            if (amount != null)
              _bankRow(tr('se_bank_amount'), '${(amount as num).toStringAsFixed(2)} €'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // späť na detail
            },
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: AppSpacing.md),
            Text(tr('registration_success_title')),
          ],
        ),
        content: Text(tr('registration_success_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to detail
            },
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate.isNotEmpty
        ? DateTime.tryParse(_birthDate) ?? DateTime(now.year - 30)
        : DateTime(now.year - 30);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18),
      locale: context.locale,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  SpiritualExercisePricing? get _selectedPricing {
    return widget.pricing.where((p) => p.roomType == _roomType).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: HomeV2.background(context),
      appBar: AppBar(
        title: Text(
          tr('registration_title'),
          style: HomeV2.serifTitle(context, size: 20),
        ),
        backgroundColor: HomeV2.background(context),
        foregroundColor: HomeV2.iconAccent(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Exercise header with image
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.homeImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: widget.homeImageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        return Container(
                          height: 160,
                          color: AppColors.primary.withValues(alpha: 0.2),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.church,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      widget.exerciseTitle,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_serverError != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _serverError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Section: Contact Information
            _buildSectionHeader(
              icon: Icons.person,
              title: tr('registration_contact_info'),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildTextField(
              label: tr('first_name'),
              value: _firstName,
              required: true,
              onChanged: (v) => setState(() => _firstName = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            _buildTextField(
              label: tr('last_name'),
              value: _lastName,
              required: true,
              onChanged: (v) => setState(() => _lastName = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            _buildTextField(
              label: tr('email'),
              value: _email,
              required: true,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => setState(() => _email = v),
              validator: (v) {
                if (v?.isEmpty == true) return tr('field_required');
                if (!_validateEmail(v!)) return tr('invalid_email');
                return null;
              },
            ),

            _buildTextField(
              label: tr('phone'),
              value: _phone,
              required: true,
              keyboardType: TextInputType.phone,
              hintText: '+421901234567',
              onChanged: (v) => setState(() => _phone = v),
              validator: (v) {
                if (v?.isEmpty == true) return tr('field_required');
                if (!_validatePhone(v!)) return tr('invalid_phone');
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Personal Information
            _buildSectionHeader(
              icon: Icons.badge,
              title: tr('registration_personal_info'),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Birth date picker
            _buildDateField(
              label: tr('birth_date'),
              value: _birthDate,
              required: true,
              onTap: _selectBirthDate,
            ),

            _buildTextField(
              label: tr('id_card_number'),
              value: _idCardNumber,
              required: true,
              hintText: 'AA123456',
              onChanged: (v) => setState(() => _idCardNumber = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Address
            _buildSectionHeader(
              icon: Icons.home,
              title: tr('registration_address'),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildTextField(
              label: tr('street'),
              value: _street,
              required: true,
              hintText: 'Hlavná 123',
              onChanged: (v) => setState(() => _street = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            _buildTextField(
              label: tr('city'),
              value: _city,
              required: true,
              onChanged: (v) => setState(() => _city = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            _buildTextField(
              label: tr('postal_code'),
              value: _postalCode,
              required: true,
              keyboardType: TextInputType.number,
              hintText: '01001',
              maxLength: 5,
              onChanged: (v) => setState(() => _postalCode = v),
              validator: (v) =>
                  v?.isEmpty == true ? tr('field_required') : null,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Church Information (optional)
            _buildSectionHeader(
              icon: Icons.church,
              title: tr('registration_church_info'),
              subtitle: tr('optional'),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildTextField(
              label: tr('parish'),
              value: _parish,
              hintText: 'Farnosť sv. Petra',
              onChanged: (v) => setState(() => _parish = v),
            ),

            _buildDropdown(
              label: tr('diocese'),
              value: _diocese,
              items: _slovakDioceses,
              onChanged: (v) => setState(() => _diocese = v ?? ''),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Accommodation
            _buildSectionHeader(
              icon: Icons.hotel,
              title: tr('registration_accommodation'),
              required: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            ...widget.pricing.map((pricing) => _buildPricingOption(pricing)),

            if (_selectedPricing != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: HomeV2.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: HomeV2.primary.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  '${tr("se_fee_label")}: ${_selectedPricing!.price.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HomeV2.textDark(context),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Section: Spôsob platby
            _buildSectionHeader(
              icon: Icons.payment,
              title: tr('se_payment_method'),
              required: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildPaymentOption(
              value: 'card',
              title: tr('se_payment_card'),
              subtitle: tr('se_payment_card_desc'),
              icon: Icons.credit_card,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildPaymentOption(
              value: 'bank',
              title: tr('se_payment_bank'),
              subtitle: tr('se_payment_bank_desc'),
              icon: Icons.account_balance,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Additional Information
            _buildSectionHeader(
              icon: Icons.info_outline,
              title: tr('registration_additional_info'),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildTextField(
              label: tr('dietary_restrictions'),
              value: _dietaryRestrictions,
              maxLines: 3,
              hintText: tr('dietary_restrictions_hint'),
              onChanged: (v) => setState(() => _dietaryRestrictions = v),
            ),

            _buildTextField(
              label: tr('notes'),
              value: _notes,
              maxLines: 3,
              hintText: tr('notes_hint'),
              onChanged: (v) => setState(() => _notes = v),
            ),

            _buildDropdown(
              label: tr('referral_source'),
              value: _referralSource,
              items: _referralSources,
              onChanged: (v) => setState(() => _referralSource = v ?? ''),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Section: Consents
            _buildSectionHeader(
              icon: Icons.verified_user,
              title: tr('registration_consents'),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildConsentCheckbox(
              value: _gdprConsent,
              required: true,
              onChanged: (v) => setState(() => _gdprConsent = v ?? false),
              label: tr('gdpr_consent_label'),
              onInfoTap: () => _showGdprInfo(),
            ),

            _buildConsentCheckbox(
              value: _responsibilityConsent,
              required: true,
              onChanged: (v) =>
                  setState(() => _responsibilityConsent = v ?? false),
              label: tr('responsibility_consent_label'),
            ),

            _buildConsentCheckbox(
              value: _newsletterConsent,
              onChanged: (v) => setState(() => _newsletterConsent = v ?? false),
              label: tr('newsletter_consent_label'),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Submit button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeV2.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HomeV2.primary.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        tr('submit_registration'),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    bool required = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.adaptiveCardTitle(context),
                    ),
                  ),
                  if (required)
                    const Text(' *', style: TextStyle(color: Colors.red)),
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool required = false,
    TextInputType? keyboardType,
    String? hintText,
    int? maxLength,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.adaptiveCardTitle(context),
                ),
              ),
              if (required)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: value,
            keyboardType: keyboardType,
            maxLength: maxLength,
            maxLines: maxLines,
            style: TextStyle(color: HomeV2.textDark(context)),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: HomeV2.textMuted(context)),
              counterText: '',
              filled: true,
              fillColor: HomeV2.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide:
                    BorderSide(color: HomeV2.primary.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide:
                    BorderSide(color: HomeV2.primary.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: const BorderSide(color: HomeV2.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: const BorderSide(color: Color(0xFFC0392B)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide:
                    const BorderSide(color: Color(0xFFC0392B), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: onChanged,
            validator: validator,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    bool required = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.adaptiveCardTitle(context),
                ),
              ),
              if (required)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: HomeV2.card(context),
                border:
                    Border.all(color: HomeV2.primary.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.isNotEmpty
                          ? DateFormat(
                              'd. MMMM yyyy',
                              context.locale.languageCode,
                            ).format(DateTime.parse(value))
                          : tr('select_date'),
                      style: TextStyle(
                        color: value.isNotEmpty
                            ? HomeV2.textDark(context)
                            : HomeV2.textMuted(context),
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today_rounded,
                      size: 20, color: HomeV2.iconAccent(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    bool required = false,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.adaptiveCardTitle(context),
                ),
              ),
              if (required)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: value.isNotEmpty ? value : null,
            style: TextStyle(fontSize: 15, color: HomeV2.textDark(context)),
            decoration: InputDecoration(
              filled: true,
              fillColor: HomeV2.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide:
                    BorderSide(color: HomeV2.primary.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide:
                    BorderSide(color: HomeV2.primary.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                borderSide: const BorderSide(color: HomeV2.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            hint: Text(tr('select_option')),
            items: items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOption(SpiritualExercisePricing pricing) {
    final theme = Theme.of(context);
    final isSelected = _roomType == pricing.roomType;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => setState(() => _roomType = pricing.roomType),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? HomeV2.primary
                  : HomeV2.primary.withValues(alpha: 0.20),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: isSelected
                ? HomeV2.primary.withValues(alpha: 0.10)
                : HomeV2.card(context),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pricing.roomType,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HomeV2.textDark(context),
                      ),
                    ),
                    if (pricing.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pricing.description!,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: HomeV2.textMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${pricing.price.toStringAsFixed(2)} €',
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? HomeV2.primary
                : HomeV2.primary.withValues(alpha: 0.20),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: isSelected
              ? HomeV2.primary.withValues(alpha: 0.10)
              : HomeV2.card(context),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? HomeV2.primary : HomeV2.textMuted(context)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HomeV2.textDark(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: HomeV2.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: HomeV2.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    bool required = false,
    VoidCallback? onInfoTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (required)
                      const TextSpan(
                        text: '* ',
                        style: TextStyle(color: Colors.red),
                      ),
                    TextSpan(text: label),
                    if (onInfoTap != null)
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: onInfoTap,
                          child: const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGdprInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('gdpr_info_title')),
        content: SingleChildScrollView(child: Text(tr('gdpr_info_content'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }
}
