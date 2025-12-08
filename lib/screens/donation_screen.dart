import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  bool _isLoading = false;
  bool _isAnonymous = false;
  final _amountController = TextEditingController(text: '10');
  final _messageController = TextEditingController();

  // Subscription tiers
  final List<Map<String, dynamic>> _subscriptionTiers = [
    {
      'tier': 'friend',
      'interval': 'month',
      'nameKey': 'donation.tiers.friend.name',
      'priceKey': 'donation.tiers.friend.price',
      'descriptionKey': 'donation.tiers.friend.description',
      'yearlyPriceKey': 'donation.tiers.friend.yearly_price',
      'yearlySavingsKey': 'donation.tiers.friend.yearly_savings',
    },
    {
      'tier': 'patron',
      'interval': 'month',
      'nameKey': 'donation.tiers.patron.name',
      'priceKey': 'donation.tiers.patron.price',
      'descriptionKey': 'donation.tiers.patron.description',
      'yearlyPriceKey': 'donation.tiers.patron.yearly_price',
      'yearlySavingsKey': 'donation.tiers.patron.yearly_savings',
      'popular': true,
    },
    {
      'tier': 'founder',
      'interval': 'month',
      'nameKey': 'donation.tiers.founder.name',
      'priceKey': 'donation.tiers.founder.price',
      'descriptionKey': 'donation.tiers.founder.description',
      'yearlyPriceKey': 'donation.tiers.founder.yearly_price',
      'yearlySavingsKey': 'donation.tiers.founder.yearly_savings',
    },
  ];

  Future<void> _makeOneTimeDonation() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 0.5) {
      _showError(tr('donation.error_min_amount'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Call backend to create checkout session
      final baseUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://lectio.one',
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/checkout/donation'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'LectioDivina-Mobile/1.0.0',
        },
        body: json.encode({
          'amount': amount,
          'userId': user?.id ?? '',
          'email': _isAnonymous ? 'stripe@lectio.one' : (user?.email ?? ''),
          'message': _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create checkout session');
      }

      final data = json.decode(response.body);
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null) {
        throw Exception('No checkout URL returned');
      }

      // Open Stripe checkout in external browser
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open browser');
      }
    } catch (e) {
      if (mounted) {
        _showError(tr('donation.error_payment', args: ['$e']));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startSubscription(String tier, String interval) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // Check if user is logged in - subscription requires account
    if (user == null) {
      _showLoginRequired();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://lectio.one',
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/checkout/subscription'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'LectioDivina-Mobile/1.0.0',
        },
        body: json.encode({
          'tier': tier,
          'interval': interval,
          'userId': user.id,
          'email': user.email ?? '',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create checkout session');
      }

      final data = json.decode(response.body);
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null) {
        throw Exception('No checkout URL returned');
      }

      // Open Stripe checkout
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open browser');
      }
    } catch (e) {
      if (mounted) {
        _showError(tr('donation.error_subscription', args: ['$e']));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('donation.login_required_title'.tr()),
        content: Text('donation.login_required_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('donation.login_required_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close donation screen
              // Navigate to login/profile screen
              // You can add navigation to login screen here
            },
            child: Text('donation.login_required_login'.tr()),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('donation.title'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'donation.header_title'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'donation.header_description'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // One-time donation section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'donation.one_time_title'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'donation.amount_label'.tr(),
                              prefixText: '€ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'donation.message_label'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            title: Text(
                              'donation.anonymous_title'.tr(),
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'donation.anonymous_subtitle'.tr(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            value: _isAnonymous,
                            onChanged: (value) =>
                                setState(() => _isAnonymous = value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _makeOneTimeDonation,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text('donation.one_time_button'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subscription section
                  Text(
                    'donation.subscription_title'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subscription tiers
                  ..._subscriptionTiers.map((tierData) {
                    final isPopular = tierData['popular'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: isPopular ? 4 : 1,
                        color: isPopular
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPopular)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'donation.popular_label'.tr(),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isPopular) const SizedBox(height: 8),
                              Text(
                                tr(tierData['nameKey'] as String),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(tierData['priceKey'] as String),
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr(tierData['descriptionKey'] as String),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _startSubscription(
                                        tierData['tier'],
                                        'month',
                                      ),
                                      child: Text(
                                        'donation.monthly_button'.tr(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _startSubscription(
                                        tierData['tier'],
                                        'year',
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tr(
                                              tierData['yearlyPriceKey']
                                                  as String,
                                            ),
                                          ),
                                          Text(
                                            tr(
                                              tierData['yearlySavingsKey']
                                                  as String,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),
                  Text(
                    'donation.stripe_disclaimer'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
