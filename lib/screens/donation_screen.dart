import 'dart:convert';

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
      'name': '💙 Priateľ Lectio',
      'price': '€3/mesiac',
      'description': 'Newsletter, e-book, 14 dní offline',
      'yearlyPrice': '€30/rok',
      'yearlySavings': 'Ušetríte €6',
    },
    {
      'tier': 'patron',
      'interval': 'month',
      'name': '💜 Patron Lectio',
      'price': '€20/mesiac',
      'description': 'Všetky kurzy ZADARMO, premium audio, fyzické dary',
      'yearlyPrice': '€200/rok',
      'yearlySavings': 'Ušetríte €40',
      'popular': true,
    },
    {
      'tier': 'founder',
      'interval': 'month',
      'name': '🌟 Zakladateľ Lectio',
      'price': '€50/mesiac',
      'description': 'LIFETIME ACCESS, hlas v rozvoji, VIP benefity',
      'yearlyPrice': '€500/rok',
      'yearlySavings': 'Ušetríte €100',
    },
  ];

  Future<void> _makeOneTimeDonation() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 0.5) {
      _showError('Minimálna suma je €0.50');
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
        _showError('Chyba pri vytváraní platby: $e');
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
        _showError('Chyba pri vytváraní predplatného: $e');
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
        title: const Text('Prihlásenie potrebné'),
        content: const Text(
          'Pre vytvorenie predplatného sa musíte najprv prihlásiť. '
          'Jednorazový dar môžete poslať aj bez prihlásenia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close donation screen
              // Navigate to login/profile screen
              // You can add navigation to login screen here
            },
            child: const Text('Prihlásiť sa'),
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
      appBar: AppBar(title: const Text('Podporte Lectio Divina')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Text(
                    '🙏 Nie predávame vieru, zdieľame ju.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Všetok obsah je ZADARMO. Vaše dary nám pomáhajú udržiavať aplikáciu a vytvárať nový obsah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // One-time donation section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💰 Jednorazový dar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Suma (EUR)',
                              prefixText: '€ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Správa (voliteľné)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            title: const Text(
                              '🕶️ Anonymný dar (bez potvrdzovacieho e-mailu)',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Platba bude spracovaná, ale nedostanete potvrdenie.',
                              style: TextStyle(
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
                              child: const Text('Darovať teraz'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subscription section
                  const Text(
                    '⭐ Mesačná podpora',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                    'Najpopulárnejšie',
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
                                tierData['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tierData['price'],
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tierData['description'],
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
                                      child: const Text('Mesačne'),
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
                                          Text(tierData['yearlyPrice']),
                                          Text(
                                            tierData['yearlySavings'],
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
                  const Text(
                    '💳 Platba je zabezpečená cez Stripe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
