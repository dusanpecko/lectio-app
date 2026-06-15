/// Formátovanie biblickej súradnice pre zobrazenie:
///  1) lokalizácia skratky evanjelia (dáta sú v SK: Mt/Mk/Lk/Jn),
///  2) normalizácia medzier → vždy „Mt 4, 4-5".
///
/// Knihy, pre ktoré nemáme mapovanie, ostávajú nezmenené (len normalizácia).
class ScriptureReference {
  ScriptureReference._();

  /// SK skratka (písmená) → skratka podľa jazyka. Mt je všade rovnaké.
  static const Map<String, Map<String, String>> _gospelMap = {
    'Mk': {'es': 'Mc', 'fr': 'Mc', 'pt-br': 'Mc'},
    'Lk': {'es': 'Lc', 'fr': 'Lc', 'pt-br': 'Lc'},
    'Jn': {'pt-br': 'Jo'},
  };

  static String _normalizeLocale(String locale) {
    final l = locale.toLowerCase();
    if (l.startsWith('pt')) return 'pt-br';
    if (l.startsWith('es')) return 'es';
    if (l.startsWith('fr')) return 'fr';
    if (l.startsWith('en')) return 'en';
    return 'sk';
  }

  static String format(String? raw, String locale) {
    final input = (raw ?? '').trim();
    if (input.isEmpty) return '';

    // Rozdeľ na knihu (príp. s poradovým číslom, napr. „1 Jn") a zvyšok.
    final m = RegExp(
      r'^((?:[1-3]\s*)?\p{L}+)\s*(.*)$',
      unicode: true,
    ).firstMatch(input);
    if (m == null) return input;

    final bookToken = m.group(1)!;
    var rest = m.group(2) ?? '';

    // Oddeľ poradové číslo (1/2/3) od abecednej časti.
    String ordinal = '';
    String letters = bookToken;
    final ord = RegExp(r'^([1-3])\s*(.*)$').firstMatch(bookToken);
    if (ord != null) {
      ordinal = '${ord.group(1)} ';
      letters = ord.group(2)!;
    }

    final loc = _normalizeLocale(locale);
    final localized = _gospelMap[letters]?[loc] ?? letters;

    // Normalizuj zvyšok: zlúč medzery + medzera po čiarke.
    rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    rest = rest.replaceAll(RegExp(r',\s*'), ', ');

    final book = '$ordinal$localized';
    return rest.isEmpty ? book : '$book $rest';
  }
}
