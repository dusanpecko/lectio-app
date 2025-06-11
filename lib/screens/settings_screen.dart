import 'package:flutter/material.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lectio_divina/services/notification_service.dart';

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
  TimeOfDay _tipTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isLoadingTipTime = true;

  @override
  void initState() {
    super.initState();
    _initPosition();
    _initBible();
    _loadTipNotificationTime();
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
    final prefs = await SharedPreferences.getInstance();
    final bible = prefs.getString('selectedBible') ?? 'biblia1';
    if (!mounted) return;
    setState(() {
      _selectedBible = bible;
      _isLoadingBible = false;
    });
  }

  Future<void> _loadTipNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('tip_hour') ?? 9;
    final minute = prefs.getInt('tip_minute') ?? 0;
    if (!mounted) return;
    setState(() {
      _tipTime = TimeOfDay(hour: hour, minute: minute);
      _isLoadingTipTime = false;
    });
  }

  Future<void> _selectTipTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _tipTime,
    );

    if (picked != null && mounted) {
      setState(() {
        _tipTime = picked;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tip_hour', picked.hour);
      await prefs.setInt('tip_minute', picked.minute);

      final locale = context.locale.languageCode;
      await NotificationService.showDailyTipNotification(
        picked.hour,
        picked.minute,
        locale,
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', value);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    setState(() => _isDeleting = true);
    await NotificationService.deleteAccount(context);
    if (mounted) {
      setState(() => _isDeleting = false);
    }
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
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserInfoCard(userEmail),
          const SizedBox(height: 16),
          _buildPositionCard(),
          const SizedBox(height: 16),
          _buildTipTimeCard(context),
          const SizedBox(height: 16),
          if (locale == 'sk') ...[
            _buildBibleCard(),
            const SizedBox(height: 16),
          ],
          if (isLoggedIn) _buildDeleteAccountCard(context),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(String email) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          tr('user'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(email),
      ),
    );
  }

  Widget _buildPositionCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app_outlined),
                const SizedBox(width: 8),
                Text(
                  tr('fab_menu_position'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTipTimeCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 8),
                Text(
                  tr('daily_tip_time'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoadingTipTime
                ? const Center(child: CircularProgressIndicator())
                : InkWell(
                    onTap: () => _selectTipTime(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm),
                          const SizedBox(width: 8),
                          Text(
                            _tipTime.format(context),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBibleCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: 8),
                Text(
                  tr('select_bible'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  tr('account'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _isDeleting ? null : () => _deleteAccount(context),
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
      ),
    );
  }
}

// Helpers remain unchanged
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
