import 'package:flutter/material.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  Future<void> _initPosition() async {
    FabMenuPosition pos = widget.currentPosition ?? await loadFabMenuPosition();
    if (mounted) {
      setState(() {
        _selectedPosition = pos;
        _isLoadingPosition = false;
      });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings')),
        backgroundColor: Colors.deepPurple,
      ),
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
