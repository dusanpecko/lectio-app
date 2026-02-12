import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spiritual_exercise.dart';
import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import '../shared/app_spacing.dart';

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

  // State
  bool _isSubmitting = false;
  String? _serverError;
  bool _isAuthenticated = false;
  bool _hasProfileData = false;

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
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      setState(() => _isAuthenticated = true);

      try {
        final profile = await supabase
            .from('users')
            .select('full_name, email, shipping_address')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          final shippingAddr =
              profile['shipping_address'] as Map<String, dynamic>?;

          final hasData =
              shippingAddr != null &&
              (shippingAddr['phone'] != null ||
                  shippingAddr['street'] != null ||
                  shippingAddr['city'] != null);

          setState(() {
            _hasProfileData = hasData;

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
      final response = await Supabase.instance.client.functions.invoke(
        'spiritual-exercise-register',
        body: {
          'exerciseSlug': widget.exerciseSlug,
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
        },
      );

      if (response.status != 200) {
        throw Exception(
          response.data?['error'] ?? 'Nepodarilo sa odoslať registráciu',
        );
      }

      if (!mounted) return;

      // Show success and offer to save profile
      if (_isAuthenticated && !_hasProfileData) {
        _showSaveProfileDialog();
      } else {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _serverError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

  void _showSaveProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('save_profile_title')),
        content: Text(tr('save_profile_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: Text(tr('no')),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final parentNavigator = Navigator.of(context);
              await _saveProfile();
              if (mounted) {
                navigator.pop();
                parentNavigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(tr('yes')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('users')
          .update({
            'full_name': '$_firstName $_lastName'.trim(),
            'shipping_address': {
              'name': '$_firstName $_lastName'.trim(),
              'email': _email,
              'phone': _phone,
              'street': _street,
              'city': _city,
              'postal_code': _postalCode,
              'country': 'Slovensko',
            },
          })
          .eq('id', user.id);
    } catch (e) {
      appLogger.e('❌ Error saving profile: $e');
    }
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
      appBar: AppBar(
        title: Text(tr('registration_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppElevation.none,
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr("price")}: ${_selectedPricing!.price.toStringAsFixed(2)} € + ${tr("deposit")}: ${(_selectedPricing!.deposit ?? 50).toStringAsFixed(2)} € = ${_selectedPricing!.totalPrice.toStringAsFixed(2)} €',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      tr('registration_deposit_info'),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  elevation: AppElevation.medium,
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
            decoration: InputDecoration(
              hintText: hintText,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Colors.red),
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
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(AppRadius.md),
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
                            ? AppColors.adaptiveCardTitle(context)
                            : Colors.grey,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, color: Colors.grey.shade600),
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
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
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
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.white,
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
                      ),
                    ),
                    if (pricing.description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        pricing.description!,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pricing.totalPrice.toStringAsFixed(2)} €',
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${pricing.price.toStringAsFixed(0)} € + ${(pricing.deposit ?? 50).toStringAsFixed(0)} € ${tr("deposit")}',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
