import 'package:flutter/material.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lectio_divina/services/notification_service.dart';

String fabMenuPositionLabel(FabMenuPosition pos) {
  switch (pos) {
    case FabMenuPosition.left:
      return tr("fab_menu_left");
    case FabMenuPosition.right:
      return tr("fab_menu_right");
    case FabMenuPosition.center:
      return tr("fab_menu_center");
    case FabMenuPosition.topLeft:
      return tr("fab_menu_top_left");
    case FabMenuPosition.topRight:
      return tr("fab_menu_top_right");
    case FabMenuPosition.topCenter:
      return tr("fab_menu_top_center");
  }
}

Future<void> saveSelectedBible(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('selectedBible', value);
}

Future<String> loadSelectedBible() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('selectedBible') ?? 'biblia1';
}

Future<void> saveFabMenuPosition(FabMenuPosition pos) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('fab_menu_position', pos.index);
}

Future<FabMenuPosition> loadFabMenuPosition() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt('fab_menu_position');
  if (index != null && index >= 0 && index < FabMenuPosition.values.length) {
    return FabMenuPosition.values[index];
  }
  return FabMenuPosition.right;
}

class SettingsScreen extends StatefulWidget {
  final FabMenuPosition? currentPosition;
  final ValueChanged<FabMenuPosition>? onPositionChanged;

  const SettingsScreen({
    super.key,
    this.currentPosition,
    this.onPositionChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late FabMenuPosition _selectedPosition;
  bool _isLoadingPosition = true;
  bool _isDeleting = false;
  String _selectedBible = 'biblia1';
  bool _isLoadingBible = true;
  TimeOfDay _quoteTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoadingNotificationTime = true;

  @override
  void initState() {
    super.initState();
    _initPosition();
    _initBible();
    _loadQuoteNotificationTime();
  }

  Future<void> _initPosition() async {
    FabMenuPosition pos = widget.currentPosition ?? await loadFabMenuPosition();
    if (!mounted) return;
    setState(() {
      _selectedPosition = pos;
      _isLoadingPosition = false;
    });
  }

  Future<void> _initBible() async {
    String bible = await loadSelectedBible();
    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _isLoadingBible = false;
    });
  }

  Future<void> _loadQuoteNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('quote_hour') ?? 9;
    final minute = prefs.getInt('quote_minute') ?? 0;
    if (!mounted) return;
    setState(() {
      _quoteTime = TimeOfDay(hour: hour, minute: minute);
      _isLoadingNotificationTime = false;
    });
  }

  Future<void> _selectQuoteTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _quoteTime,
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _quoteTime = picked;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quote_hour', picked.hour);
      await prefs.setInt('quote_minute', picked.minute);

      const String quote = '„Tvoje slovo je svetlo pre moje nohy.“';
      await NotificationService.showDailyQuoteNotification(
        picked.hour,
        picked.minute,
        quote,
      );
    }
  }

  Future<void> _onPositionChanged(FabMenuPosition? pos) async {
    if (pos == null) return;
    setState(() {
      _selectedPosition = pos;
    });
    await saveFabMenuPosition(pos);
    widget.onPositionChanged?.call(pos);
  }

  Future<void> _onBibleChanged(String? value) async {
    if (value == null) return;
    setState(() {
      _selectedBible = value;
    });
    await saveSelectedBible(value);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await supabase.functions.invoke(
        'delete_user',
        body: {
          'user': {'id': user.id},
        },
      );
      if (response.status == 200) {
        await supabase.auth.signOut();
        if (!mounted) return;
        bool? deleted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('account_deleted_title')),
            content: Text(tr('account_deleted_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
        if (deleted == true && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('error')),
            content: Text('${tr('account_delete_failed')}: ${response.data}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('error')),
          content: Text('${tr('account_delete_failed')}: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('delete_account_title')),
        content: Text(tr('delete_account_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAccount(context);
            },
            child: Text(tr('delete_account')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final userEmail = session?.user.email ?? tr('guest');
    final isLoggedIn = session != null;
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(tr('user')),
            subtitle: Text(userEmail),
          ),
          const SizedBox(height: 24),
          Text(
            tr('fab_menu_position'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _isLoadingPosition
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<FabMenuPosition>(
                  value: _selectedPosition,
                  onChanged: _onPositionChanged,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  items: FabMenuPosition.values.map((pos) {
                    return DropdownMenuItem(
                      value: pos,
                      child: Text(fabMenuPositionLabel(pos)),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 32),
          Text(
            tr('daily_quote_time'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _isLoadingNotificationTime
              ? const Center(child: CircularProgressIndicator())
              : ListTile(
                  title: Text(
                    '${_quoteTime.hour.toString().padLeft(2, '0')}:${_quoteTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _selectQuoteTime(context),
                ),
          const SizedBox(height: 32),
          if (locale == 'sk') ...[
            Text(
              tr('select_bible'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _isLoadingBible
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedBible,
                    onChanged: _onBibleChanged,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'biblia1',
                        child: Text(tr('bible_1')),
                      ),
                      DropdownMenuItem(
                        value: 'biblia2',
                        child: Text(tr('bible_2')),
                      ),
                      DropdownMenuItem(
                        value: 'biblia3',
                        child: Text(tr('bible_3')),
                      ),
                    ],
                  ),
            const SizedBox(height: 32),
          ] else if (locale == 'en') ...[
            Text(
              tr('bible_en_only'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(tr('bible_en_desc')),
            ),
            const SizedBox(height: 32),
          ],
          Text(
            tr('settings_coming_soon'),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (isLoggedIn)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  tr('account'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isDeleting
                      ? null
                      : () => _showDeleteAccountDialog(context),
                  icon: const Icon(Icons.delete_forever),
                  label: _isDeleting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(tr('delete_account')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
