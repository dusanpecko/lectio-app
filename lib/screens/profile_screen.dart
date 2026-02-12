import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/app_colors.dart';
import '../utils/app_logger.dart';
import 'notification_settings_screen.dart';
import 'spiritual_exercise_detail_screen.dart';
import '../shared/app_spacing.dart';

// Data models
class Subscription {
  final String id;
  final String tier;
  final double amount;
  final String status;
  final String interval;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  Subscription({
    required this.id,
    required this.tier,
    required this.amount,
    required this.status,
    required this.interval,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      tier: json['tier'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      interval: json['interval'] ?? 'month',
      currentPeriodEnd: DateTime.parse(
        json['current_period_end'] ?? DateTime.now().toIso8601String(),
      ),
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
    );
  }
}

class Donation {
  final String id;
  final double amount;
  final DateTime createdAt;
  final String? message;

  Donation({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.message,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      message: json['message'],
    );
  }
}

class SpiritualExerciseRegistration {
  final int id;
  final DateTime createdAt;
  final String roomType;
  final String paymentStatus;
  final String status;
  final String firstName;
  final String lastName;
  final Map<String, dynamic> spiritualExercise;

  SpiritualExerciseRegistration({
    required this.id,
    required this.createdAt,
    required this.roomType,
    required this.paymentStatus,
    required this.status,
    required this.firstName,
    required this.lastName,
    required this.spiritualExercise,
  });

  factory SpiritualExerciseRegistration.fromJson(Map<String, dynamic> json) {
    return SpiritualExerciseRegistration(
      id: json['id'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      roomType: json['room_type'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      status: json['status'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      spiritualExercise: json['spiritual_exercise'] ?? {},
    );
  }
}

// Bank Payment model
class BankPayment {
  final String id;
  final DateTime transactionDate;
  final double amount;
  final String currency;
  final String? paymentType;
  final String? payerReference;

  BankPayment({
    required this.id,
    required this.transactionDate,
    required this.amount,
    required this.currency,
    this.paymentType,
    this.payerReference,
  });

  factory BankPayment.fromJson(Map<String, dynamic> json) {
    return BankPayment(
      id: json['id'] ?? '',
      transactionDate: DateTime.parse(
        json['transaction_date'] ?? DateTime.now().toIso8601String(),
      ),
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'EUR',
      paymentType: json['payment_type'],
      payerReference: json['payer_reference'],
    );
  }
}

// Payment History Item (combined)
class PaymentHistoryItem {
  final String id;
  final String type; // 'subscription', 'donation', 'bank_payment'
  final double amount;
  final DateTime date;
  final String description;
  final String? status;

  PaymentHistoryItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.status,
  });
}

// Billing Info model
class BillingInfo {
  final Map<String, dynamic>? shippingAddress;
  final Map<String, dynamic>? billingAddress;
  final String? companyName;
  final String? ico;
  final String? dic;
  final String? iban;

  BillingInfo({
    this.shippingAddress,
    this.billingAddress,
    this.companyName,
    this.ico,
    this.dic,
    this.iban,
  });

  factory BillingInfo.fromJson(Map<String, dynamic> json) {
    return BillingInfo(
      shippingAddress: json['shipping_address'],
      billingAddress: json['billing_address'],
      companyName: json['company_name'],
      ico: json['ico'],
      dic: json['dic'],
      iban: json['iban'],
    );
  }

  bool get hasAnyData =>
      shippingAddress != null ||
      billingAddress != null ||
      companyName != null ||
      ico != null ||
      dic != null ||
      iban != null;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  String? _role;
  String? _avatarUrl;
  String? _variableSymbol;
  DateTime? _registeredAt;
  bool _isSaving = false;
  bool _isUploading = false;

  // New data
  List<Subscription> _subscriptions = [];
  List<Donation> _donations = [];
  List<SpiritualExerciseRegistration> _exerciseRegistrations = [];
  List<BankPayment> _bankPayments = [];
  List<PaymentHistoryItem> _paymentHistory = [];
  BillingInfo? _billingInfo;

  // Billing editing state
  bool _editingBilling = false;
  bool _savingBilling = false;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _icoCtrl;
  late TextEditingController _dicCtrl;
  late TextEditingController _ibanCtrl;
  // Shipping address
  late TextEditingController _shippingStreetCtrl;
  late TextEditingController _shippingCityCtrl;
  late TextEditingController _shippingZipCtrl;
  late TextEditingController _shippingCountryCtrl;
  late TextEditingController _shippingPhoneCtrl;
  late TextEditingController _shippingEmailCtrl;
  // Billing address
  late TextEditingController _billingStreetCtrl;
  late TextEditingController _billingCityCtrl;
  late TextEditingController _billingZipCtrl;
  late TextEditingController _billingCountryCtrl;
  late TextEditingController _billingPhoneCtrl;
  late TextEditingController _billingEmailCtrl;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: user?.email ?? '');

    // Initialize billing controllers
    _companyNameCtrl = TextEditingController();
    _icoCtrl = TextEditingController();
    _dicCtrl = TextEditingController();
    _ibanCtrl = TextEditingController();
    _shippingStreetCtrl = TextEditingController();
    _shippingCityCtrl = TextEditingController();
    _shippingZipCtrl = TextEditingController();
    _shippingCountryCtrl = TextEditingController();
    _shippingPhoneCtrl = TextEditingController();
    _shippingEmailCtrl = TextEditingController();
    _billingStreetCtrl = TextEditingController();
    _billingCityCtrl = TextEditingController();
    _billingZipCtrl = TextEditingController();
    _billingCountryCtrl = TextEditingController();
    _billingPhoneCtrl = TextEditingController();
    _billingEmailCtrl = TextEditingController();

    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      fetchFullName(),
      fetchRole(),
      fetchRegisteredAt(),
      _fetchSubscriptions(),
      _fetchDonations(),
      _fetchExerciseRegistrations(),
      _fetchBankPayments(),
      _fetchBillingInfo(),
    ]);
    _buildPaymentHistory();
  }

  Future<void> fetchFullName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('full_name, avatar_url, variable_symbol')
        .eq('id', user.id)
        .maybeSingle();
    if (data != null && mounted) {
      setState(() {
        _nameCtrl.text = data['full_name'] ?? '';
        _avatarUrl = data['avatar_url'];
        _variableSymbol = data['variable_symbol'];
      });
    }
  }

  Future<void> fetchRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      _role = data?['role'] ?? 'user';
    });
  }

  Future<void> fetchRegisteredAt() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('created_at')
        .eq('id', user.id)
        .maybeSingle();
    if (data != null && data['created_at'] != null) {
      try {
        setState(() {
          _registeredAt = DateTime.parse(data['created_at']);
        });
      } catch (_) {
        // Ignore invalid date format
      }
    }
  }

  Future<void> _fetchSubscriptions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _subscriptions = (data as List)
              .map((e) => Subscription.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      appLogger.e('Error fetching subscriptions: $e');
    }
  }

  Future<void> _fetchDonations() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('donations')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _donations = (data as List).map((e) => Donation.fromJson(e)).toList();
        });
      }
    } catch (e) {
      appLogger.e('Error fetching donations: $e');
    }
  }

  Future<void> _fetchExerciseRegistrations() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('spiritual_exercises_registrations')
          .select('''
            *,
            spiritual_exercise:spiritual_exercises(
              id, title, slug, start_date, end_date, 
              location_name, location_city, image_url
            )
          ''')
          .eq('email', user.email!)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _exerciseRegistrations = (data as List)
              .map((e) => SpiritualExerciseRegistration.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      appLogger.e('Error fetching exercise registrations: $e');
    }
  }

  Future<void> _fetchBankPayments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('bank_payments')
          .select(
            'id, transaction_date, amount, currency, payment_type, payer_reference',
          )
          .eq('user_id', user.id)
          .eq('matched', true)
          .order('transaction_date', ascending: false);
      if (mounted) {
        setState(() {
          _bankPayments = (data as List)
              .map((e) => BankPayment.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      appLogger.e('Error fetching bank payments: $e');
    }
  }

  Future<void> _fetchBillingInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('users')
          .select(
            'shipping_address, billing_address, company_name, ico, dic, iban',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        final billingInfo = BillingInfo.fromJson(data);
        setState(() {
          _billingInfo = billingInfo;

          // Fill controllers
          _companyNameCtrl.text = billingInfo.companyName ?? '';
          _icoCtrl.text = billingInfo.ico ?? '';
          _dicCtrl.text = billingInfo.dic ?? '';
          _ibanCtrl.text = billingInfo.iban ?? '';

          // Shipping address
          if (billingInfo.shippingAddress != null) {
            _shippingStreetCtrl.text =
                billingInfo.shippingAddress!['street'] ?? '';
            _shippingCityCtrl.text = billingInfo.shippingAddress!['city'] ?? '';
            _shippingZipCtrl.text = billingInfo.shippingAddress!['zip'] ?? '';
            _shippingCountryCtrl.text =
                billingInfo.shippingAddress!['country'] ?? '';
            _shippingPhoneCtrl.text =
                billingInfo.shippingAddress!['phone'] ?? '';
            _shippingEmailCtrl.text =
                billingInfo.shippingAddress!['email'] ?? '';
          }

          // Billing address
          if (billingInfo.billingAddress != null) {
            _billingStreetCtrl.text =
                billingInfo.billingAddress!['street'] ?? '';
            _billingCityCtrl.text = billingInfo.billingAddress!['city'] ?? '';
            _billingZipCtrl.text = billingInfo.billingAddress!['zip'] ?? '';
            _billingCountryCtrl.text =
                billingInfo.billingAddress!['country'] ?? '';
            _billingPhoneCtrl.text = billingInfo.billingAddress!['phone'] ?? '';
            _billingEmailCtrl.text = billingInfo.billingAddress!['email'] ?? '';
          }
        });
      }
    } catch (e) {
      appLogger.e('Error fetching billing info: $e');
    }
  }

  void _buildPaymentHistory() {
    final history = <PaymentHistoryItem>[];

    // Add subscriptions
    for (final sub in _subscriptions) {
      history.add(
        PaymentHistoryItem(
          id: sub.id,
          type: 'subscription',
          amount: sub.amount,
          date: sub.currentPeriodEnd,
          description:
              '${sub.tier} tier - ${sub.interval == 'month' ? 'profile.payment.monthly'.tr() : 'profile.payment.yearly'.tr()}',
          status: sub.status,
        ),
      );
    }

    // Add donations
    for (final donation in _donations) {
      history.add(
        PaymentHistoryItem(
          id: donation.id,
          type: 'donation',
          amount: donation.amount,
          date: donation.createdAt,
          description: donation.message ?? 'profile.payment.one_time'.tr(),
        ),
      );
    }

    // Add bank payments
    for (final payment in _bankPayments) {
      final typeLabel = switch (payment.paymentType) {
        'donation' => 'profile.payment.type.donation'.tr(),
        'shop' => 'profile.payment.type.shop'.tr(),
        'subscription' => 'profile.payment.type.subscription'.tr(),
        _ => 'profile.payment.type.bank'.tr(),
      };
      history.add(
        PaymentHistoryItem(
          id: payment.id,
          type: 'bank_payment',
          amount: payment.amount,
          date: payment.transactionDate,
          description: '$typeLabel - VS: ${payment.payerReference ?? 'N/A'}',
        ),
      );
    }

    // Sort by date (newest first)
    history.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _paymentHistory = history;
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('users')
          .update({'full_name': _nameCtrl.text.trim()})
          .eq('id', user.id);
      await supabase.auth.updateUser(
        UserAttributes(email: _emailCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.snackbar.saved'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'profile.snackbar.save_failed'.tr(args: [e.toString()]),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBillingInfo() async {
    setState(() => _savingBilling = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _savingBilling = false);
      return;
    }

    try {
      // Prepare shipping address
      Map<String, dynamic>? shippingAddress;
      if (_shippingStreetCtrl.text.isNotEmpty ||
          _shippingCityCtrl.text.isNotEmpty ||
          _shippingZipCtrl.text.isNotEmpty) {
        shippingAddress = {
          'street': _shippingStreetCtrl.text.trim(),
          'city': _shippingCityCtrl.text.trim(),
          'zip': _shippingZipCtrl.text.trim(),
          'country': _shippingCountryCtrl.text.trim(),
          'phone': _shippingPhoneCtrl.text.trim(),
          'email': _shippingEmailCtrl.text.trim(),
        };
      }

      // Prepare billing address
      Map<String, dynamic>? billingAddress;
      if (_billingStreetCtrl.text.isNotEmpty ||
          _billingCityCtrl.text.isNotEmpty ||
          _billingZipCtrl.text.isNotEmpty) {
        billingAddress = {
          'street': _billingStreetCtrl.text.trim(),
          'city': _billingCityCtrl.text.trim(),
          'zip': _billingZipCtrl.text.trim(),
          'country': _billingCountryCtrl.text.trim(),
          'phone': _billingPhoneCtrl.text.trim(),
          'email': _billingEmailCtrl.text.trim(),
        };
      }

      await supabase
          .from('users')
          .update({
            'shipping_address': shippingAddress,
            'billing_address': billingAddress,
            'company_name': _companyNameCtrl.text.trim().isEmpty
                ? null
                : _companyNameCtrl.text.trim(),
            'ico': _icoCtrl.text.trim().isEmpty ? null : _icoCtrl.text.trim(),
            'dic': _dicCtrl.text.trim().isEmpty ? null : _dicCtrl.text.trim(),
            'iban': _ibanCtrl.text.trim().isEmpty
                ? null
                : _ibanCtrl.text.trim(),
          })
          .eq('id', user.id);

      await _fetchBillingInfo();

      if (mounted) {
        setState(() => _editingBilling = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.snackbar.saved'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'profile.snackbar.save_failed'.tr(args: [e.toString()]),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBilling = false);
    }
  }

  Future<void> changePassword() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('profile.password2.title'.tr()),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.current'.tr(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'profile.password2.current_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.new'.tr(),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'profile.password2.min_length'.tr();
                        }
                        if (v == currentPassCtrl.text) {
                          return 'profile.password2.same_as_current'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.confirm'.tr(),
                      ),
                      validator: (v) => v != newPassCtrl.text
                          ? 'profile.password2.not_match'.tr()
                          : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    'profile.button.cancel'.tr(),
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => isLoading = true);
                          try {
                            final email = supabase.auth.currentUser?.email;
                            if (email == null) throw Exception('Chýba email');
                            final signInResp = await supabase.auth
                                .signInWithPassword(
                                  email: email,
                                  password: currentPassCtrl.text,
                                );
                            if (signInResp.user == null) {
                              setState(() {
                                error = 'profile.password2.incorrect_current'
                                    .tr();
                                isLoading = false;
                              });
                              return;
                            }
                            await supabase.auth.updateUser(
                              UserAttributes(password: newPassCtrl.text),
                            );
                            if (mounted) navigator.pop();
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'profile.password2.changed'.tr(),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              error = 'profile.snackbar.error'.tr(
                                args: [e.toString()],
                              );
                              isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('profile.button.save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showAvatarPicker() async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.avatar.camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                changeAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.avatar.gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                changeAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> changeAvatar(ImageSource source) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await picked.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) throw Exception('Neplatný obrázok');

      img.Image thumbnail = img.copyResizeCropSquare(original, size: 400);

      Uint8List jpg = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 75));

      final fileExt = 'jpg';
      final filePath =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            jpg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final avatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      await supabase
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      setState(() {
        _avatarUrl = avatarUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.avatar.changed'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.avatar.error'.tr(args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> downloadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // Načítaj všetky užívateľské dáta
      final userData = await supabase
          .from('users')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      // Načítaj poznámky používateľa
      final notes = await supabase
          .from('notes')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Načítaj preferencie notifikácií
      final notificationPrefs = await supabase
          .from('user_notification_preferences')
          .select('*, notification_topics(*)')
          .eq('user_id', user.id);

      // Vytvor kompletný export
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'user_info': {
          'id': user.id,
          'email': user.email,
          'full_name': userData?['full_name'],
          'role': userData?['role'],
          'created_at': userData?['created_at'],
          'avatar_url': userData?['avatar_url'],
        },
        'notes': notes,
        'notification_preferences': notificationPrefs,
        'metadata': {
          'app': 'Lectio Divina',
          'version': '1.0',
          'format': 'JSON',
        },
      };

      // Konvertuj na JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Ulož do dočasného súboru
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final fileName = 'lectio_divina_export_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      if (mounted) {
        setState(() => _isSaving = false);

        // Zisti pozíciu pre iOS popover
        final box = context.findRenderObject() as RenderBox?;
        final sharePositionOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        // Zobraz možnosti zdieľania
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'profile.download.export_title'.tr(),
            text: 'profile.download.export_description'.tr(),
            sharePositionOrigin: sharePositionOrigin,
          ),
        );

        if (result.status == ShareResultStatus.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('profile.download.success'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.download.error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Potvrdenie pred vymazaním
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('profile.delete.confirm_title'.tr()),
          content: Text('profile.delete.confirm_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'profile.button.cancel'.tr(),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: Text('profile.delete.confirm_button'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      // Získaj aktuálnu session token
      final session = supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final token = session.accessToken;

      // Zavolaj backend API endpoint pre vymazanie účtu
      final backendUrl =
          dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://www.lectio.one';

      final response = await http.delete(
        Uri.parse('$backendUrl/api/user/delete-account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 207) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to delete account');
      }

      // Odhláš používateľa lokálne
      await supabase.auth.signOut();

      if (mounted) {
        // Presmeruj na login obrazovku
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.delete.success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.delete.error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyNameCtrl.dispose();
    _icoCtrl.dispose();
    _dicCtrl.dispose();
    _ibanCtrl.dispose();
    _shippingStreetCtrl.dispose();
    _shippingCityCtrl.dispose();
    _shippingZipCtrl.dispose();
    _shippingCountryCtrl.dispose();
    _shippingPhoneCtrl.dispose();
    _shippingEmailCtrl.dispose();
    _billingStreetCtrl.dispose();
    _billingCityCtrl.dispose();
    _billingZipCtrl.dispose();
    _billingCountryCtrl.dispose();
    _billingPhoneCtrl.dispose();
    _billingEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'profile.button.logout'.tr(),
            onPressed: signOut,
          ),
        ],
      ),
      body: user == null
          ? Center(child: Text("profile.not_logged".tr()))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Avatar Card
                  _buildAvatarCard(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Profile Info Card
                  _buildProfileInfoCard(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons Card
                  _buildActionButtonsCard(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Billing Info Section
                  _buildBillingInfoSection(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // My Subscriptions (expandable)
                  if (_subscriptions.isNotEmpty) ...[
                    _buildSubscriptionsCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // My Donations (expandable)
                  if (_donations.isNotEmpty) ...[
                    _buildDonationsCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Spiritual Exercise Registrations
                  if (_exerciseRegistrations.isNotEmpty) ...[
                    _buildExerciseRegistrationsCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Bank Payments (expandable)
                  if (_bankPayments.isNotEmpty) ...[
                    _buildBankPaymentsCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Payment History (expandable)
                  if (_paymentHistory.isNotEmpty) ...[
                    _buildPaymentHistoryCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('profile.button.save_changes'.tr()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Delete Account Button
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : deleteAccount,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: Text('profile.button.delete_account'.tr()),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isUploading ? null : showAvatarPicker,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gradient ring for supporters
                  if (_subscriptions.isNotEmpty)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _subscriptions.any((s) => s.tier == 'founder')
                              ? [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                  Colors.deepPurple.shade700,
                                ]
                              : _subscriptions.any((s) => s.tier == 'patron')
                              ? [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                  Colors.indigo.shade700,
                                ]
                              : [
                                  Colors.amber.shade400,
                                  Colors.orange.shade500,
                                  Colors.deepOrange.shade600,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                          ),
                        ),
                      ),
                    ),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage:
                        (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(
                            Icons.person,
                            size: 48,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: _isUploading ? null : showAvatarPicker,
              icon: const Icon(Icons.photo_camera, size: 18),
              label: Text('profile.avatar.change'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'profile.field.fullname'.tr(),
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'profile.field.fullname_required'.tr()
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: Icon(Icons.email, color: theme.colorScheme.primary),
              title: Text('profile.field.email'.tr()),
              subtitle: Text(_emailCtrl.text),
              contentPadding: EdgeInsets.zero,
            ),
            if (_registeredAt != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.event, color: theme.colorScheme.primary),
                title: Text('profile.field.registered_at'.tr()),
                subtitle: Text(
                  '${_registeredAt!.day.toString().padLeft(2, '0')}.'
                  '${_registeredAt!.month.toString().padLeft(2, '0')}.'
                  '${_registeredAt!.year}',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.verified_user,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.field.role'.tr()),
              subtitle: Text(_role ?? 'profile.field.role_loading'.tr()),
              contentPadding: EdgeInsets.zero,
            ),
            // Variable Symbol
            if (_variableSymbol != null && _variableSymbol!.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.tag, color: theme.colorScheme.primary),
                title: Text('profile.field.variable_symbol'.tr()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _variableSymbol!,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'profile.field.variable_symbol_hint'.tr(),
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            // Support Status
            if (_subscriptions.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.star, color: theme.colorScheme.primary),
                title: Text('profile.support_status'.tr()),
                subtitle: Text(
                  _subscriptions.any((s) => s.tier == 'founder')
                      ? '🏆 ${'profile.tier.founder'.tr()}'
                      : _subscriptions.any((s) => s.tier == 'patron')
                      ? '💎 ${'profile.tier.patron'.tr()}'
                      : '❤️ ${'profile.tier.friend'.tr()}',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _subscriptions.any((s) => s.tier == 'founder')
                        ? Colors.purple.shade600
                        : _subscriptions.any((s) => s.tier == 'patron')
                        ? Colors.blue.shade600
                        : Colors.red.shade500,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _subscriptions.any((s) => s.tier == 'founder')
                        ? 'profile.tier_badge.founder'.tr()
                        : _subscriptions.any((s) => s.tier == 'patron')
                        ? 'profile.tier_badge.patron'.tr()
                        : 'profile.tier_badge.friend'.tr(),
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.lock_reset, color: theme.colorScheme.primary),
              title: Text('profile.button.change_password'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: changePassword,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.notifications,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.button.notification_settings'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.download, color: theme.colorScheme.primary),
              title: Text('profile.button.download_data'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSaving ? null : downloadUserData,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.credit_card, color: Colors.purple, size: 20),
        ),
        title: Text(
          'profile.section.subscriptions'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_subscriptions.length} ${'profile.subscription.active'.tr().toLowerCase()}',
        ),
        children: _subscriptions
            .map((sub) => _buildSubscriptionItem(theme, sub))
            .toList(),
      ),
    );
  }

  Widget _buildSubscriptionItem(ThemeData theme, Subscription sub) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profile.subscription.tier'.tr(args: [sub.tier.toUpperCase()]),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'profile.subscription.active'.tr(),
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '€${sub.amount.toStringAsFixed(2)}/${sub.interval == 'month' ? 'profile.subscription.monthly'.tr() : 'profile.subscription.yearly'.tr()}',
            style: theme.textTheme.titleLarge!.copyWith( fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${'profile.subscription.next_payment'.tr()}: ${DateFormat('dd.MM.yyyy').format(sub.currentPeriodEnd)}',
            style: theme.textTheme.bodySmall!.copyWith( color: Colors.grey.shade600),
          ),
          if (sub.cancelAtPeriodEnd) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Text(
                '${'profile.subscription.cancels_on'.tr()} ${DateFormat('dd.MM.yyyy').format(sub.currentPeriodEnd)}',
                style: theme.textTheme.bodySmall!.copyWith( color: Colors.yellow.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonationsCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.favorite, color: Colors.red, size: 20),
        ),
        title: Text(
          'profile.section.donations'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_donations.length} ${'profile.payment.one_time'.tr()}',
        ),
        children: _donations
            .map((donation) => _buildDonationItem(theme, donation))
            .toList(),
      ),
    );
  }

  Widget _buildDonationItem(ThemeData theme, Donation donation) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '€${donation.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat('dd.MM.yyyy').format(donation.createdAt),
                  style: theme.textTheme.bodySmall!.copyWith( color: Colors.grey.shade600),
                ),
                if (donation.message != null &&
                    donation.message!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '"${donation.message}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.favorite, color: theme.colorScheme.primary, size: 32),
        ],
      ),
    );
  }

  Widget _buildExerciseRegistrationsCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.church, color: AppColors.primary, size: 20),
        ),
        title: Text(
          'profile.section.exercise_registrations'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('${_exerciseRegistrations.length}'),
        children: _exerciseRegistrations
            .map((reg) => _buildExerciseRegistrationCard(theme, reg))
            .toList(),
      ),
    );
  }

  Widget _buildExerciseRegistrationCard(
    ThemeData theme,
    SpiritualExerciseRegistration reg,
  ) {
    final theme = Theme.of(context);
    final exercise = reg.spiritualExercise;
    final startDate = exercise['start_date'] != null
        ? DateTime.parse(exercise['start_date'])
        : null;
    final endDate = exercise['end_date'] != null
        ? DateTime.parse(exercise['end_date'])
        : null;

    Color statusColor;
    String statusText;
    switch (reg.paymentStatus) {
      case 'paid':
        statusColor = Colors.green;
        statusText = 'profile.registration.paid'.tr();
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'profile.registration.pending'.tr();
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'profile.registration.cancelled'.tr();
        break;
      default:
        statusColor = Colors.grey;
        statusText = reg.paymentStatus;
    }

    return GestureDetector(
      onTap: () {
        if (exercise['slug'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SpiritualExerciseDetailScreen(slug: exercise['slug']),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (exercise['image_url'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: CachedNetworkImage(
                  imageUrl: exercise['image_url'],
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Container(
                    height: 120,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(
                        Icons.church,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise['title'] ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          statusText,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (startDate != null && endDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (exercise['location_name'] != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${exercise['location_name']}${exercise['location_city'] != null ? ', ${exercise['location_city']}' : ''}',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${reg.firstName} ${reg.lastName} • ${reg.roomType}',
                    style: theme.textTheme.bodySmall!.copyWith( color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format address Map to String
  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['postal_code'] != null) parts.add(address['postal_code']);
    if (address['country'] != null) parts.add(address['country']);
    return parts.join(', ');
  }

  // Billing Info Section Widget
  Widget _buildBillingInfoSection(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'profile.section.billing_info'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_editingBilling)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _editingBilling = true),
                    tooltip: 'profile.button.edit'.tr(),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_editingBilling) ...[
              // Edit mode
              Text(
                'profile.billing.company_name'.tr(),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _companyNameCtrl,
                decoration: InputDecoration(
                  hintText: 'profile.billing.company_name'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _icoCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.ico'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _dicCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.dic'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _ibanCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.iban'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Shipping Address
              Text(
                'profile.billing.shipping_address'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _shippingStreetCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.street'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _shippingCityCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.billing.city'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _shippingZipCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.billing.zip'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _shippingCountryCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.country'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _shippingPhoneCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.phone'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _shippingEmailCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.email'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Billing Address
              Text(
                'profile.billing.billing_address'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _billingStreetCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.street'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _billingCityCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.billing.city'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _billingZipCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.billing.zip'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _billingCountryCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.country'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _billingPhoneCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.phone'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _billingEmailCtrl,
                decoration: InputDecoration(
                  labelText: 'profile.billing.email'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Save/Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _savingBilling
                          ? null
                          : () => setState(() => _editingBilling = false),
                      child: Text('profile.button.cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savingBilling ? null : _saveBillingInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: _savingBilling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('profile.button.save'.tr()),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Read-only mode
              if (_billingInfo == null || !_billingInfo!.hasAnyData)
                Text(
                  'profile.billing.no_data'.tr(),
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else ...[
                if (_billingInfo!.companyName != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.apartment,
                    'profile.billing.company_name'.tr(),
                    _billingInfo!.companyName!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_billingInfo!.ico != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.numbers,
                    'profile.billing.ico'.tr(),
                    _billingInfo!.ico!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_billingInfo!.dic != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.account_balance,
                    'profile.billing.dic'.tr(),
                    _billingInfo!.dic!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_billingInfo!.iban != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.credit_card,
                    'profile.billing.iban'.tr(),
                    _billingInfo!.iban!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_billingInfo!.shippingAddress != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.local_shipping,
                    'profile.billing.shipping_address'.tr(),
                    _formatAddress(_billingInfo!.shippingAddress!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_billingInfo!.billingAddress != null) ...[
                  _buildBillingInfoRow(
                    theme,
                    Icons.business,
                    'profile.billing.billing_address'.tr(),
                    _formatAddress(_billingInfo!.billingAddress!),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillingInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Bank Payments Section Widget
  Widget _buildBankPaymentsCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.account_balance,
            color: Colors.cyan,
            size: 20,
          ),
        ),
        title: Text(
          'profile.section.bank_payments'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_bankPayments.length} ${_bankPayments.length == 1 ? 'profile.payment.singular'.tr() : 'profile.payment.plural'.tr()}',
        ),
        children: _bankPayments
            .map((payment) => _buildBankPaymentItem(theme, payment))
            .toList(),
      ),
    );
  }

  Widget _buildBankPaymentItem(ThemeData theme, BankPayment payment) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentType ??
                      'profile.bank_payment.unknown_type'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd.MM.yyyy').format(payment.transactionDate),
                  style: theme.textTheme.bodySmall!.copyWith( color: Colors.grey.shade600),
                ),
                if (payment.payerReference != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'VS: ${payment.payerReference}',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(ThemeData theme) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: AppElevation.medium,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.history, color: Colors.indigo, size: 20),
        ),
        title: Text(
          'profile.section.payment_history'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_paymentHistory.length} ${_paymentHistory.length == 1 ? 'profile.payment.singular'.tr() : 'profile.payment.plural'.tr()}',
        ),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: _paymentHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final payment = entry.value;
                final isLast = index == _paymentHistory.length - 1;
                return _buildPaymentHistoryRow(theme, payment, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryRow(
    ThemeData theme,
    PaymentHistoryItem payment,
    bool isLast,
  ) {
    final theme = Theme.of(context);
    IconData icon;
    Color iconColor;

    switch (payment.type) {
      case 'subscription':
        icon = Icons.credit_card;
        iconColor = Colors.purple.shade600;
        break;
      case 'donation':
        icon = Icons.favorite;
        iconColor = Colors.red.shade600;
        break;
      case 'bank':
        icon = Icons.account_balance;
        iconColor = Colors.cyan.shade600;
        break;
      default:
        icon = Icons.payment;
        iconColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('dd.MM.yyyy').format(payment.date),
                  style: theme.textTheme.bodySmall!.copyWith( color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${payment.amount.toStringAsFixed(2)} €',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (payment.status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        payment.status == 'active' ||
                            payment.status == 'succeeded'
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    payment.status!,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color:
                          payment.status == 'active' ||
                              payment.status == 'succeeded'
                          ? Colors.green.shade800
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
