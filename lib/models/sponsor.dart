// Model sponzora pre sekciu „Podporili nás" (home pod tvorcami + O aplikácii).
// Dáta z verejného API `/api/sponsors?lang=…` — server už vybral jazyk popisu
// a skryl sumu, ak nie je verejná. Appka nič nefiltruje ani nerozhoduje.

String? _opt(dynamic v) {
  final s = v?.toString().trim();
  return (s != null && s.isNotEmpty) ? s : null;
}

double? _dbl(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.logoDarkUrl,
    required this.websiteUrl,
    required this.amount,
    required this.currency,
  });

  final String id;
  final String name;
  /// Popis v jazyku používateľa (fallback rieši server); môže byť prázdny.
  final String description;
  final String? logoUrl;
  /// Voliteľné logo pre tmavý režim; bez neho sa kreslí [logoUrl] na bielej dlaždici.
  final String? logoDarkUrl;
  final String? websiteUrl;
  /// Len ak admin sumu zverejnil, inak null.
  final double? amount;
  final String currency;

  factory Sponsor.fromJson(Map<String, dynamic> j) => Sponsor(
        id: j['id'].toString(),
        name: _opt(j['name']) ?? '',
        description: _opt(j['description']) ?? '',
        logoUrl: _opt(j['logoUrl']),
        logoDarkUrl: _opt(j['logoDarkUrl']),
        websiteUrl: _opt(j['websiteUrl']),
        amount: _dbl(j['amount']),
        currency: _opt(j['currency']) ?? 'EUR',
      );
}
