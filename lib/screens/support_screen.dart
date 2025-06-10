import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic>? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('support_stats')
        .select()
        .order('year', ascending: false)
        .limit(1)
        .maybeSingle();

    if (mounted) {
      setState(() {
        stats = response;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageAsset = 'assets/images/podporte.png';

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Podporte tento projekt')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Podporte tento projekt')),
        body: const Center(child: Text('Dáta nie sú dostupné')),
      );
    }

    final supported = (stats?['supported_amount'] as num?)?.toDouble() ?? 0.0;
    final target = (stats?['target_amount'] as num?)?.toDouble() ?? 1.0;
    final year = stats?['year'] ?? DateTime.now().year;
    final updatedAt = stats?['updated_at'];
    final updatedDate = updatedAt != null
        ? DateTime.parse(updatedAt).toLocal()
        : DateTime.now();
    final lastUpdated =
        "${updatedDate.day.toString().padLeft(2, '0')}.${updatedDate.month.toString().padLeft(2, '0')}.${updatedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text('Podporte tento projekt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            // Card s progres kruhom a obrázkom
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        imageAsset,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Už podporené\nna rok $year",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF686ea3),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 140,
                            width: 140,
                            child: CircularProgressIndicator(
                              value: target == 0
                                  ? 0
                                  : (supported / target).clamp(0.0, 1.0),
                              strokeWidth: 14,
                              backgroundColor: const Color(0xFFebeaf7),
                              color: const Color(0xFF686ea3),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${supported.toInt()} z ${target.toInt()} €",
                                style: const TextStyle(
                                  color: Color(0xFF686ea3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "aktualizované: $lastUpdated",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    // Darovacie tlačidlo - musí byť vnútri Column
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.volunteer_activism),
                          label: const Text(
                            "Darovať online",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4A5085),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            const donateUrl =
                                'https://dcza.24-pay.sk/darovat/lectio-divina';
                            final uri = Uri.parse(donateUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nepodarilo sa otvoriť stránku.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Card s textom o projekte
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Ahojte, priatelia Lectio divina!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF686ea3),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Aktualizované 11.1.2025",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Veríme, že aj vy, rovnako ako my, vnímate túto aplikáciu ako skvelý nástroj pre každého, kto chce prehĺbiť svoj duchovný život a objaviť krásu Božieho slova.\n\n"
                      "Od spustenia 1. novembra 2022 si ju stiahlo viac ako 23-tisíc ľudí a bola spustená neuveriteľných 1,2 milióna krát! Zaregistrovalo sa 1720 používateľov a aktívne ju používa až 6545 ľudí.\n\n"
                      "Čo sme pre vás v roku 2024 pripravili?\n\n"
                      "- Aktualizovali sme zdrojové kódy pre Android a Apple.\n"
                      "- Pridali sme nové funkcie, ako napríklad možnosť robiť si poznámky.\n"
                      "- Vylepšili sme domovskú stránku a zobrazovanie Lectio divina.\n"
                      "- Zapracovali sme aj na grafických úpravách, aby bolo používanie aplikácie ešte príjemnejšie.\n\n"
                      "Ako môžete podporiť Lectio divina?\n"
                      "Aj naša aplikácia potrebuje na svoje fungovanie financie. Do konca roka 2023 sme do projektu investovali 13 800 € z vlastných zdrojov a vašich darov. V roku 2024 to bolo 6 340 €.\n\n"
                      "V roku 2025 predpokladáme náklady vo výške 7 200 €, a to najmä na:\n"
                      "- Server a serverové služby (1 200 €)\n"
                      "- Údržbu a aktualizáciu modulov (3 500 €)\n"
                      "- Grafické služby a iné výdavky (1 000 €)\n"
                      "- Nahrávaciu techniku (1 500 €)\n\n"
                      "Okrem toho budeme potrebovať financie aj na pracovnú silu, ktorá sa stará o tvorbu a pridávanie obsahu do aplikácie.\n\n"
                      "Každý príspevok, či už malý alebo veľký, nám pomôže udržať túto aplikáciu živú a rozvíjať ju ďalej. ❤️\n\n"
                      "Pre firmy: Využite možnosť charitatívnej reklamy a podporte náš projekt! Zviditeľnite svoju značku a zároveň pomôžete dobrej veci. Kontaktujte nás pre viac informácií.\n\n"
                      "Pomôcť nám však môžete aj inak:\n"
                      "- Šírte informácie o aplikácii medzi svojimi priateľmi a rodinou.\n"
                      "- Podeľte sa o svoje skúsenosti s aplikáciou na sociálnych sieťach.\n"
                      "- Modlite sa za náš projekt a za všetkých, ktorí sa na ňom podieľajú.\n\n"
                      "Veríme, že spoločne môžeme priniesť do sveta viac svetla a pomôcť ľuďom prehĺbiť ich vzťah s Bohom prostredníctvom Svätého písma.\n\n"
                      "Bližšie informácie o finančnej podpore projektu Lectio divina nájdete vo vašej aplikácii a na web stránke www.lectiodivina.sk\n\n"
                      "Ďakujeme za vašu podporu! ❤️\n\n"
                      "S úprimnou vďakou\n"
                      "Dušan Pecko, autor projektu Lectio divina a riaditeľ Pastoračného fondu Žilinskej diecézy - KROK.\n\n"
                      "P.S.: Za každého používateľa slúžim raz mesačne svätú omšu ako poďakovanie, že vám záleží na vašom duchovnom raste.",
                      style: TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

            // Darovacie tlačidlo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text(
                    "Darovať online",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4A5085),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    const donateUrl =
                        'https://dcza.24-pay.sk/darovat/lectio-divina';
                    final uri = Uri.parse(donateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nepodarilo sa otvoriť stránku.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),

            // Card s platobnými údajmi
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Chcete sa stať finančným podporovateľom?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF686ea3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Je to jednoduché! Zaregistrujte sa na mojkrok.sk, vyberte si projekt \"Lectio divina\" a posielajte mesačne aspoň 2 eurá.",
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Prispieť môžete:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      "- Bankovým prevodom: po prihlásení na mojkrok.sk\n"
                      "- Poštovým poukazom: po prihlásení na mojkrok.sk",
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Nechcete sa registrovať?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    // IBAN & SWIFT s kopírovaním
                    const SizedBox(height: 8),
                    _CopyRow(
                      label: "IBAN:",
                      value: "SK04 8330 0000 0029 0168 8673",
                    ),
                    const SizedBox(height: 6),
                    _CopyRow(label: "SWIFT:", value: "FIOZSKBAXXX"),
                    const SizedBox(height: 6),
                    const Text(
                      "- Do poznámky uveďte: Lectio divina",
                      style: TextStyle(fontSize: 15),
                    ),
                    const Text("- VS 11770001", style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),
                    const Text(
                      "Potrebujete viac informácií?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Kontaktujte nás:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.phone, size: 18, color: Color(0xFF4A5085)),
                        SizedBox(width: 6),
                        Text("0903 982 982"),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.email, size: 18, color: Color(0xFF4A5085)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "dusan.pecko@dcza.sk",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20, color: Colors.deepPurple),
          tooltip: "Skopírovať",
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$label $value skopírované")),
            );
          },
        ),
      ],
    );
  }
}
