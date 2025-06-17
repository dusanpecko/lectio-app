import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';

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

    if (!mounted) return;
    setState(() {
      stats = response;
      isLoading = false;
    });
  }

  Future<void> _tryOpenDonateUrl(BuildContext context) async {
    const donateUrl = 'https://dcza.24-pay.sk/darovat/lectio-divina';
    final uri = Uri.parse(donateUrl);

    final canLaunchIt = await canLaunchUrl(uri);
    if (canLaunchIt) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Xiaomi/MIUI notice + option to copy
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('support2.open_fail_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Html(data: tr('support2.miui_notice')),
              const SizedBox(height: 16),
              SelectableText(donateUrl, style: const TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: donateUrl));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('support2.copied_link'))),
                );
              },
              child: Text(tr('support2.copy_link')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('support2.close')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final cardColor = theme.cardColor;
    final onPrimary = theme.colorScheme.onPrimary;
    final onSurface = theme.colorScheme.onSurface;
    final imageAsset = 'assets/images/podporte.png';

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
      appBar: AppBar(
        title: Html(data: tr('support2.title')),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : stats == null
          ? Center(child: Html(data: tr('support2.nodata')))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                children: [
                  Card(
                    color: cardColor,
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
                          Html(
                            data: tr(
                              'support2.supported',
                              namedArgs: {'year': '$year'},
                            ),
                            style: {
                              "*": Style(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: FontSize(18),
                                textAlign: TextAlign.center,
                              ),
                            },
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 160,
                            width: 160,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  height: 150,
                                  width: 150,
                                  child: CircularProgressIndicator(
                                    value: target == 0
                                        ? 0
                                        : (supported / target).clamp(0.0, 1.0),
                                    strokeWidth: 14,
                                    backgroundColor: const Color(0xFFE3E8F5),
                                    color: color,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Html(
                                      data: tr(
                                        'support2.amount',
                                        namedArgs: {
                                          'supported': supported
                                              .toInt()
                                              .toString(),
                                          'target': target.toInt().toString(),
                                        },
                                      ),
                                      style: {
                                        "*": Style(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: FontSize(17),
                                          textAlign: TextAlign.center,
                                        ),
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Html(
                            data: tr(
                              'support2.updated',
                              namedArgs: {'date': lastUpdated},
                            ),
                            style: {
                              "*": Style(
                                color: onSurface.withOpacity(0.6),
                                fontSize: FontSize(13),
                              ),
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.volunteer_activism),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () => _tryOpenDonateUrl(context),
                                label: Center(
                                  child: Html(
                                    data: tr("support2.donate_online"),
                                    style: {
                                      "*": Style(
                                        fontWeight: FontWeight.bold,
                                        fontSize: FontSize(16),
                                        margin: Margins.zero,
                                        textAlign: TextAlign.center,
                                      ),
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _AboutProjectCard(),
                  const _BankCard(),
                ],
              ),
            ),
    );
  }
}

// --- ostatné karty ostávajú rovnaké ako v predošlej verzii ---

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Html(
          data: label.tr(),
          style: {
            "*": Style(
              fontWeight: FontWeight.w600,
              fontSize: FontSize(15),
              color: color,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
          },
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
          icon: Icon(Icons.copy, size: 20, color: color),
          tooltip: "support2.copy".tr(),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Html(
                  data: tr(
                    'support2.copied',
                    namedArgs: {'label': label, 'value': value},
                  ),
                  style: {
                    "*": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AboutProjectCard extends StatelessWidget {
  const _AboutProjectCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Html(
              data: tr("support2.hello"),
              style: {
                "*": Style(
                  fontWeight: FontWeight.bold,
                  fontSize: FontSize(18),
                  color: color,
                  margin: Margins.zero,
                ),
              },
            ),
            const SizedBox(height: 4),
            Html(
              data: tr("support2.updated_label"),
              style: {
                "*": Style(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                  fontSize: FontSize(13),
                  margin: Margins.zero,
                ),
              },
            ),
            const SizedBox(height: 12),
            Html(
              data: tr("support2.about_text"),
              style: {
                "*": Style(
                  fontSize: FontSize(15.0),
                  lineHeight: LineHeight(1.6),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Html(
              data: tr("support2.become_supporter"),
              style: {
                "*": Style(
                  fontWeight: FontWeight.bold,
                  fontSize: FontSize(17),
                  color: color,
                  margin: Margins.zero,
                ),
              },
            ),
            const SizedBox(height: 8),
            Html(
              data: tr("support2.easy_register"),
              style: {
                "*": Style(fontSize: FontSize(15), lineHeight: LineHeight(1.5)),
              },
            ),
            const SizedBox(height: 12),
            Html(
              data: tr("support2.can_contribute"),
              style: {
                "*": Style(fontWeight: FontWeight.bold, fontSize: FontSize(15)),
              },
            ),
            Html(
              data: tr("support2.how_contribute"),
              style: {"*": Style(fontSize: FontSize(15))},
            ),
            const SizedBox(height: 12),
            Html(
              data: tr("support2.no_registration"),
              style: {
                "*": Style(fontWeight: FontWeight.bold, fontSize: FontSize(15)),
              },
            ),
            const SizedBox(height: 8),
            _CopyRow(
              label: "support2.iban",
              value: "SK04 8330 0000 0029 0168 8673",
            ),
            const SizedBox(height: 6),
            _CopyRow(label: "support2.swift", value: "FIOZSKBAXXX"),
            const SizedBox(height: 6),
            Html(
              data: tr("support2.note"),
              style: {"*": Style(fontSize: FontSize(15))},
            ),
            Html(
              data: tr("support2.vs"),
              style: {"*": Style(fontSize: FontSize(15))},
            ),
            const SizedBox(height: 12),
            Html(
              data: tr("support2.need_info"),
              style: {
                "*": Style(fontWeight: FontWeight.bold, fontSize: FontSize(15)),
              },
            ),
            const SizedBox(height: 4),
            Html(
              data: tr("support2.contact_us"),
              style: {"*": Style(fontWeight: FontWeight.bold)},
            ),
            Row(
              children: [
                Icon(Icons.phone, size: 18, color: color),
                const SizedBox(width: 6),
                Text("0903 982 982"),
              ],
            ),
            Row(
              children: [
                Icon(Icons.email, size: 18, color: color),
                const SizedBox(width: 6),
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
    );
  }
}
