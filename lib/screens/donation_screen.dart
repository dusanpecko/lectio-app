import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_logger.dart';

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

  // Stripe Price IDs
  static const Map<String, Map<String, String>> _stripePriceIds = {
    'friend': {
      'year': 'price_1SVYYiGrGKpSpokkQMrIqRYL', // €30/year
      // No monthly option for friend tier
    },
    'patron': {
      'year': 'price_1SVYbMGrGKpSpokkP0a2Bbo4', // €200/year
      'month': 'price_1SQYSSGrGKpSpokkCSnAuMPr', // €20/month
    },
    'founder': {
      'year': 'price_1SVYd9GrGKpSpokkbvQ0nXeG', // €500/year
      'month': 'price_1SQYauGrGKpSpokkHQhkJUhe', // €50/month
    },
  };

  // Subscription tiers
  final List<Map<String, dynamic>> _subscriptionTiers = [
    {
      'tier': 'prayer',
      'name': '🙏 Modlím sa',
      'subtitle': 'Nefinačná podpora',
      'price': '€0',
      'description': 'Tichá podpora má veľkú silu.',
      'features': [
        'Pridávam sa k modlitbovému reťazcu za lectio.one',
        'Denne sa modlím Lectio Divina',
        'Mesačný e-mail s modlitbovými úmyslami (voľiteľné)',
        'Bez záväzkov, bez platby',
      ],
      'isPrayer': true,
    },
    {
      'tier': 'friend',
      'name': '🤝 Priateľ',
      'subtitle': 'Ročná podpora projektu',
      'price': '€30 / rok',
      'description': 'Pomáhate, aby modlitba zostala dostupná pre všetkých.',
      'features': [
        'Jednorazový dar na 12 mesiacov',
        'Označenie „Priateľ“ v profile',
        'Ďakovný e-mail a krátky ročný report',
        'Podpora vývoja a lokalizácie',
      ],
      'yearlyPrice': '€30/rok',
    },
    {
      'tier': 'patron',
      'name': '🕊 Patrón',
      'subtitle': 'Stály pilier projektu',
      'price': '€200 / rok',
      'monthlyPrice': '€20 / mesiac',
      'description': 'Vaša podpora dáva projektu stabilitu a smer.',
      'features': [
        'Označenie „Patrón“ v profile',
        'Skorší prístup k novému obsahu a funkciám',
        'Early access k pripravovaným kurzom Lectio Divina',
        'Možnosť hlasovať o nových funkciách',
      ],
      'popular': true,
      'yearlyPrice': '€200/rok',
    },
    {
      'tier': 'founder',
      'name': '🌟 Zakladateľ',
      'subtitle': 'Výnimočná podpora projektu',
      'price': '€500 / rok',
      'monthlyPrice': '€50 / mesiac',
      'description': 'Pomáhate niesť toto dielo výrazným spôsobom.',
      'features': [
        'Všetko z úrovne Patrón',
        'Ročný žurnál Lectio (tlačený alebo PDF podľa dostupnosti)',
        'Osobné poďakovanie',
        '(Voľiteľne) uvedenie medzi „Zakladateľmi“',
      ],
      'yearlyPrice': '€500/rok',
    },
  ];

  Future<void> _makeOneTimeDonation() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1.0) {
      _showError('Minimálna suma je €1.00');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Call backend to create checkout session
      final baseUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://www.lectio.one',
      );

      appLogger.d('🔵 Creating donation checkout: €$amount');
      appLogger.d('🌐 Target URL: $baseUrl/api/checkout/donation');
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

      appLogger.d('📡 API Response status: ${response.statusCode}');
      appLogger.d('📡 API Response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ?? 'Failed to create checkout session',
        );
      }

      final data = json.decode(response.body);
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned from server');
      }

      appLogger.d('🌐 Opening Stripe checkout: $checkoutUrl');

      // Open Stripe checkout in external browser
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Nepodarilo sa otvoriť prehliadač. Skúste to neskôr.');
      }

      appLogger.d('✅ Browser opened successfully');
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

    // Get Stripe price ID for this tier and interval
    final priceId = _stripePriceIds[tier]?[interval];
    if (priceId == null) {
      _showError('Neplatná kombinácia tier a intervalu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://www.lectio.one',
      );

      appLogger.d(
        '🔵 Creating subscription checkout: tier=$tier, interval=$interval, priceId=$priceId',
      );
      appLogger.d('🌐 Target URL: $baseUrl/api/checkout/subscription');
      final response = await http.post(
        Uri.parse('$baseUrl/api/checkout/subscription'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'LectioDivina-Mobile/1.0.0',
        },
        body: json.encode({
          'tier': tier,
          'priceId': priceId,
          'userId': user.id,
          'email': user.email ?? '',
        }),
      );

      appLogger.d('📡 API Response status: ${response.statusCode}');
      appLogger.d('📡 API Response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ?? 'Failed to create checkout session',
        );
      }

      final data = json.decode(response.body);
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned from server');
      }

      appLogger.d('🌐 Opening Stripe checkout: $checkoutUrl');

      // Open Stripe checkout in external browser
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Nepodarilo sa otvoriť prehliadač. Skúste to neskôr.');
      }

      appLogger.d('✅ Browser opened successfully');
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
          'Pre vytvorenie predplatného sa musíte najprv prihlásiť.\nJednorazový dar môžete poslať aj bez prihlásenia.',
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Hero App Bar
                SliverAppBar(
                  expandedHeight: 280,
                  floating: false,
                  pinned: true,
                  backgroundColor: theme.colorScheme.primary,
                  title: const Text(
                    '🤍 Podporte lectio.one',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/donation_bg.webp',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.favorite_outline_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Podporte lectio.one',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Priestor ticha pre Božie slovo',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        const Text(
                          'lectio.one vzniká z túžby vytvorať priestor ticha pre Božie slovo v digitálnom svete.\n'
                          'Každý deň sa ľudia modlia, rozjímajú a nachádzajú pokoj vďaka tejto službe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ak cítite, že chcete toto dielo niesť spolu s nami, môžete si vybrať spôsob podpory, ktorý je vám blízky.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          '🌿 Spôsoby podpory',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

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
                                    labelText: 'Správa (voľiteľné)',
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
                                  onChanged: (value) => setState(
                                    () => _isAnonymous = value ?? false,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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

                        // Subscription tiers - Horizontal slider
                        SizedBox(
                          height: 520,
                          child: PageView.builder(
                            controller: PageController(
                              initialPage: 1, // Start with "Priateľ" tier
                              viewportFraction: 0.9,
                            ),
                            itemCount: _subscriptionTiers.length,
                            itemBuilder: (context, index) {
                              final tierData = _subscriptionTiers[index];
                              final isPopular = tierData['popular'] == true;
                              final isPrayer = tierData['isPrayer'] == true;
                              final features =
                                  tierData['features'] as List<String>? ?? [];

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Card(
                                  elevation: isPopular ? 4 : 2,
                                  color: isPopular
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Popular badge
                                        if (isPopular)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
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

                                        // Tier name
                                        Text(
                                          tierData['name'] as String,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isPopular
                                                ? Colors.white
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Subtitle
                                        Text(
                                          tierData['subtitle'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isPopular
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Price
                                        Text(
                                          tierData['price'] as String,
                                          style: TextStyle(
                                            fontSize: 28,
                                            color: isPopular
                                                ? Colors.white
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        // Monthly price alternative
                                        if (tierData.containsKey(
                                          'monthlyPrice',
                                        ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'alebo ${tierData['monthlyPrice']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isPopular
                                                    ? Colors.white70
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 16),

                                        // Features
                                        ...features.map(
                                          (feature) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '• ',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: isPopular
                                                        ? Colors.white
                                                        : Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    feature,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      height: 1.4,
                                                      color: isPopular
                                                          ? Colors.white
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // Description
                                        Text(
                                          tierData['description'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: isPopular
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),

                                        // Action buttons (only for non-prayer tiers)
                                        if (!isPrayer) ...[
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _startSubscription(
                                                        tierData['tier'],
                                                        'year',
                                                      ),
                                                  style: isPopular
                                                      ? ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.white,
                                                          foregroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                        )
                                                      : null,
                                                  child: const Text('Ročne'),
                                                ),
                                              ),
                                              if (tierData.containsKey(
                                                'monthlyPrice',
                                              )) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () =>
                                                        _startSubscription(
                                                          tierData['tier'],
                                                          'month',
                                                        ),
                                                    style: isPopular
                                                        ? OutlinedButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.white,
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 1.5,
                                                                ),
                                                          )
                                                        : null,
                                                    child: const Text(
                                                      'Mesačne',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Bank transfer section
                        Card(
                          color: Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🏦 Podpora bankovým prevodom',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Ak chcete podporiť lectio.one priamo prevodom na účet:',
                                  style: TextStyle(fontSize: 14, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                const _CopyRow(
                                  label: 'Názov účtu:',
                                  value: 'lectio.one',
                                ),
                                const SizedBox(height: 8),
                                const _CopyRow(
                                  label: 'IBAN:',
                                  value: 'SK42 7500 0000 0040 3515 6222',
                                ),
                                const SizedBox(height: 8),
                                const _CopyRow(
                                  label: 'BIC (SWIFT):',
                                  value: 'CEKOSKBX',
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Ďakujeme za vašu dôveru a podporu.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Tax support section
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🌾 Podpora cez 2 % alebo 3 % z daní',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'lectio.one je občianske združenie.\n'
                                  'Ak chcete podporiť túto službu, môžete nám venovať 2 % (alebo 3 % pri dobrovoľníctve) z vašich daní.',
                                  style: TextStyle(fontSize: 14, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Údaje prijímateľa',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Názov: lectio.one\n'
                                  'Právna forma: Občianske združenie\n'
                                  'IČO: 55971521\n'
                                  'Sídlo: Jána Kalinčiaka 3098/1, 010 01 Žilina',
                                  style: TextStyle(fontSize: 13, height: 1.6),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Dôležité termíny',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'do 31. marca – podanie daňového priznania\n'
                                  'do 30. apríla – podanie vyhlásenia zamestnancami\n'
                                  '(Ak ste dobrovoľníčili aspoň 40 hodín, môžete poukázať 3 %.)',
                                  style: TextStyle(fontSize: 13, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Footer
                        const Text(
                          '🙏 Ďakujeme',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vaša podpora nám umožňuje rozvíjať lectio.one\n'
                          'a prinášať viac pokoja, nádeje a radosti do života ľudí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aplikácia je bez reklám, bez rozptyľovania a dostupná bezplatne.\n'
                          'Ak chcete, môžete jej rozvoj podporiť svojím darom.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '💳 Platba je zabezpečená cez Stripe',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

// Helper widget for copyable rows
class _CopyRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, size: 20, color: color),
          tooltip: "Skopírovať",
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label $value skopírované'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
