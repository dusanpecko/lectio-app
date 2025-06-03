import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../shared/fab_menu_position.dart';
import '../screens/auth_screen.dart';

class AppFloatingMenu extends StatelessWidget {
  final Function(String) onTap;
  final FabMenuPosition position;

  const AppFloatingMenu({
    super.key,
    required this.onTap,
    this.position = FabMenuPosition.right,
  });

  Alignment _getAlignment() {
    switch (position) {
      case FabMenuPosition.right:
        return Alignment.bottomRight;
      case FabMenuPosition.left:
        return Alignment.bottomLeft;
      case FabMenuPosition.center:
        return Alignment.bottomCenter;
      case FabMenuPosition.topRight:
        return Alignment.topRight;
      case FabMenuPosition.topLeft:
        return Alignment.topLeft;
      case FabMenuPosition.topCenter:
        return Alignment.topCenter;
    }
  }

  String getAuthLabel(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? tr('sign_in') : tr('sign_out');
  }

  IconData getAuthIcon() {
    return Supabase.instance.client.auth.currentSession == null
        ? Icons.login
        : Icons.logout;
  }

  Color getAuthColor(ThemeData theme) {
    return Supabase.instance.client.auth.currentSession == null
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: _getAlignment(),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: FloatingActionButton(
          foregroundColor:
              theme.floatingActionButtonTheme.foregroundColor ?? Colors.white,
          backgroundColor:
              theme.floatingActionButtonTheme.backgroundColor ??
              theme.colorScheme.primary,
          onPressed: () => _showMenu(context),
          child: const Icon(Icons.menu),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildMenu(context),
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      isScrollControlled: false,
      useSafeArea: true,
    );
    if (!context.mounted) return; // bezpečnostná kontrola

    if (result != null) {
      if (result == 'auth') {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        } else {
          await Supabase.instance.client.auth.signOut();
        }
      } else {
        onTap(result);
      }
    }
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);
    final session = Supabase.instance.client.auth.currentSession;
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.home, color: theme.colorScheme.primary),
            title: Text(tr('home')),
            onTap: () => Navigator.pop(context, 'home'),
          ),
          ListTile(
            leading: Icon(Icons.menu_book, color: theme.colorScheme.primary),
            title: Text(tr('lectio_divina')),
            onTap: () => Navigator.pop(context, 'lectio'),
          ),
          ListTile(
            leading: Icon(Icons.campaign, color: theme.colorScheme.primary),
            title: Text(tr('news')),
            onTap: () => Navigator.pop(context, 'news'),
          ),
          // --- Položka pre poznámky bude len pre prihlásených ---
          if (session != null)
            ListTile(
              leading: Icon(Icons.note, color: theme.colorScheme.primary),
              title: Text(tr('notes_title')),
              onTap: () => Navigator.pop(context, 'notes'),
            ),
          // ------------------------------------------------------
          ListTile(
            leading: Icon(Icons.settings, color: theme.colorScheme.primary),
            title: Text(tr('settings')),
            onTap: () => Navigator.pop(context, 'settings'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(getAuthIcon(), color: getAuthColor(theme)),
            title: Text(getAuthLabel(context)),
            onTap: () => Navigator.pop(context, 'auth'),
          ),
        ],
      ),
    );
  }
}
