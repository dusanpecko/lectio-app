import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lectio_divina/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  String _selectedBible = 'biblia1';
  bool _isLoadingBible = true;

  @override
  void initState() {
    super.initState();
    _initBible();
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

  Future<void> _onBibleChanged(String? value) async {
    if (value == null) return;
    setState(() => _selectedBible = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBible', value);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Pozn.: z klienta nevieme "zmazať" účet bez serverovej funkcie.
    // Tu aspoň odhlásime používateľa; ak máš RPC na delete, zavolaj ho sem.
    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('signed_out'))));
      Navigator.of(context).pop(); // zatvor Settings po odhlásení (ak chceš)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error_generic'))));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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
          _buildUserInfoCard(context, userEmail),
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

  Widget _buildUserInfoCard(BuildContext context, String email) {
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
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
