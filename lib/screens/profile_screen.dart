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

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: user?.email ?? '');
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
        setState(() {
          _billingInfo = BillingInfo.fromJson(data);
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
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
          dotenv.env['NEXT_PUBLIC_BACKEND_URL'] ?? 'https://lectio.one';

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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _isUploading ? null : showAvatarPicker,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gradient ring for supporters (Priateľ program)
                          if (_subscriptions.isNotEmpty)
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors:
                                      _subscriptions.any(
                                        (s) => s.tier == 'founder',
                                      )
                                      ? [
                                          Colors.purple.shade400,
                                          Colors.purple.shade600,
                                          Colors.deepPurple.shade700,
                                        ]
                                      : _subscriptions.any(
                                          (s) => s.tier == 'patron',
                                        )
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
                                padding: const EdgeInsets.all(4),
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
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
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
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isUploading ? null : showAvatarPicker,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: Text('profile.avatar.change'.tr()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.field.fullname'.tr(),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'profile.field.fullname_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      leading: Icon(
                        Icons.email,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text('profile.field.email'.tr()),
                      subtitle: Text(_emailCtrl.text),
                    ),
                    const SizedBox(height: 14),
                    if (_registeredAt != null) ...[
                      ListTile(
                        leading: Icon(
                          Icons.event,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text('profile.field.registered_at'.tr()),
                        subtitle: Text(
                          '${_registeredAt!.day.toString().padLeft(2, '0')}.'
                          '${_registeredAt!.month.toString().padLeft(2, '0')}.'
                          '${_registeredAt!.year}',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    ListTile(
                      leading: Icon(
                        Icons.verified_user,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text('profile.field.role'.tr()),
                      subtitle: Text(
                        _role ?? 'profile.field.role_loading'.tr(),
                      ),
                    ),
                    // Variable Symbol
                    if (_variableSymbol != null &&
                        _variableSymbol!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.cyan.shade50, Colors.blue.shade50],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyan.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyan.shade500,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'profile.field.variable_symbol'.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.cyan.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _variableSymbol!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    'profile.field.variable_symbol_hint'.tr(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Supporter Badge
                    if (_subscriptions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade50,
                              Colors.yellow.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade500,
                                    Colors.yellow.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text(
                                  '⭐',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'profile.support_status'.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                  Text(
                                    _subscriptions.any(
                                          (s) => s.tier == 'founder',
                                        )
                                        ? '🏆 ${'profile.tier.founder'.tr()}'
                                        : _subscriptions.any(
                                            (s) => s.tier == 'patron',
                                          )
                                        ? '💎 ${'profile.tier.patron'.tr()}'
                                        : '❤️ ${'profile.tier.friend'.tr()}',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _subscriptions.any(
                                      (s) => s.tier == 'founder',
                                    )
                                    ? Colors.purple.shade600
                                    : _subscriptions.any(
                                        (s) => s.tier == 'patron',
                                      )
                                    ? Colors.blue.shade600
                                    : Colors.red.shade500,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _subscriptions.any((s) => s.tier == 'founder')
                                    ? 'profile.tier_badge.founder'.tr()
                                    : _subscriptions.any(
                                        (s) => s.tier == 'patron',
                                      )
                                    ? 'profile.tier_badge.patron'.tr()
                                    : 'profile.tier_badge.friend'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: changePassword,
                      icon: Icon(
                        Icons.lock_reset,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text('profile.button.change_password'.tr()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationSettingsScreen(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.notifications,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text('profile.button.notification_settings'.tr()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : downloadUserData,
                      icon: Icon(
                        Icons.download,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text('profile.button.download_data'.tr()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
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
                    const SizedBox(height: 24),

                    // Subscriptions Section
                    if (_subscriptions.isNotEmpty) ...[
                      _buildSectionHeader(
                        theme,
                        Icons.credit_card,
                        'profile.section.subscriptions'.tr(),
                        Colors.purple,
                      ),
                      const SizedBox(height: 12),
                      ..._subscriptions.map(
                        (sub) => _buildSubscriptionCard(theme, sub),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Donations Section
                    if (_donations.isNotEmpty) ...[
                      _buildSectionHeader(
                        theme,
                        Icons.favorite,
                        'profile.section.donations'.tr(),
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      ..._donations.map(
                        (donation) => _buildDonationCard(theme, donation),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Spiritual Exercise Registrations Section
                    if (_exerciseRegistrations.isNotEmpty) ...[
                      _buildSectionHeader(
                        theme,
                        Icons.church,
                        'profile.section.exercise_registrations'.tr(),
                        AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      ..._exerciseRegistrations.map(
                        (reg) => _buildExerciseRegistrationCard(theme, reg),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Bank Payments Section
                    _buildBankPaymentsSection(theme),

                    // Billing Info Section
                    _buildBillingInfoSection(theme),

                    // Combined Payment History Section
                    _buildPaymentHistorySection(theme),

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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme, Subscription sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'profile.subscription.active'.tr(),
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '€${sub.amount.toStringAsFixed(2)}/${sub.interval == 'month' ? 'profile.subscription.monthly'.tr() : 'profile.subscription.yearly'.tr()}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${'profile.subscription.next_payment'.tr()}: ${DateFormat('dd.MM.yyyy').format(sub.currentPeriodEnd)}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (sub.cancelAtPeriodEnd) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Text(
                '${'profile.subscription.cancels_on'.tr()} ${DateFormat('dd.MM.yyyy').format(sub.currentPeriodEnd)}',
                style: TextStyle(fontSize: 12, color: Colors.yellow.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonationCard(ThemeData theme, Donation donation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
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
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM.yyyy').format(donation.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (donation.message != null &&
                    donation.message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
          Icon(Icons.favorite, color: Colors.red.shade500, size: 32),
        ],
      ),
    );
  }

  Widget _buildExerciseRegistrationCard(
    ThemeData theme,
    SpiritualExerciseRegistration reg,
  ) {
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.all(16),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (exercise['location_name'] != null) ...[
                    const SizedBox(height: 4),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${reg.firstName} ${reg.lastName} • ${reg.roomType}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
    if (_billingInfo == null) return const SizedBox.shrink();

    final hasAnyData =
        _billingInfo!.shippingAddress != null ||
        _billingInfo!.billingAddress != null ||
        _billingInfo!.companyName != null ||
        _billingInfo!.ico != null ||
        _billingInfo!.dic != null ||
        _billingInfo!.iban != null;

    if (!hasAnyData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          Icons.receipt_long,
          'profile.section.billing_info'.tr(),
          Colors.teal,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_billingInfo!.shippingAddress != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.local_shipping,
                  'profile.billing.shipping_address'.tr(),
                  _formatAddress(_billingInfo!.shippingAddress!),
                ),
                const SizedBox(height: 12),
              ],
              if (_billingInfo!.billingAddress != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.business,
                  'profile.billing.billing_address'.tr(),
                  _formatAddress(_billingInfo!.billingAddress!),
                ),
                const SizedBox(height: 12),
              ],
              if (_billingInfo!.companyName != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.apartment,
                  'profile.billing.company_name'.tr(),
                  _billingInfo!.companyName!,
                ),
                const SizedBox(height: 12),
              ],
              if (_billingInfo!.ico != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.numbers,
                  'profile.billing.ico'.tr(),
                  _billingInfo!.ico!,
                ),
                const SizedBox(height: 12),
              ],
              if (_billingInfo!.dic != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.account_balance,
                  'profile.billing.dic'.tr(),
                  _billingInfo!.dic!,
                ),
                const SizedBox(height: 12),
              ],
              if (_billingInfo!.iban != null) ...[
                _buildBillingInfoRow(
                  theme,
                  Icons.credit_card,
                  'profile.billing.iban'.tr(),
                  _billingInfo!.iban!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
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
        Icon(icon, size: 18, color: Colors.teal.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
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
  Widget _buildBankPaymentsSection(ThemeData theme) {
    if (_bankPayments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          Icons.account_balance,
          'profile.section.bank_payments'.tr(),
          Colors.cyan,
        ),
        const SizedBox(height: 12),
        ..._bankPayments.map(
          (payment) => _buildBankPaymentCard(theme, payment),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBankPaymentCard(ThemeData theme, BankPayment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyan.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.cyan.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance,
              color: Colors.cyan.shade700,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (payment.payerReference != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'VS: ${payment.payerReference}',
                    style: TextStyle(
                      fontSize: 11,
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
              color: Colors.cyan.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // Combined Payment History Section Widget
  Widget _buildPaymentHistorySection(ThemeData theme) {
    if (_paymentHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          Icons.history,
          'profile.section.payment_history'.tr(),
          Colors.indigo,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPaymentHistoryRow(
    ThemeData theme,
    PaymentHistoryItem payment,
    bool isLast,
  ) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.indigo.shade200, width: 1),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  color: Colors.indigo.shade800,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.status!,
                    style: TextStyle(
                      fontSize: 10,
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
