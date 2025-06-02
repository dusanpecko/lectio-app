import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  String getAuthLabel() {
    return Supabase.instance.client.auth.currentSession == null
        ? 'Prihlásiť sa'
        : 'Odhlásiť sa';
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
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              builder: (context) => _buildMenu(context),
              backgroundColor: theme.cardColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            );
            if (result != null) {
              if (result == 'auth') {
                final session = Supabase.instance.client.auth.currentSession;
                if (session == null) {
                  // Prihlásiť sa – naviguj na AuthScreen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                } else {
                  await Supabase.instance.client.auth.signOut();
                  // Navigáciu netreba, SessionHandler to vybaví
                }
              } else {
                onTap(result);
              }
            }
          },
          child: const Icon(Icons.menu),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      children: [
        ListTile(
          leading: Icon(Icons.home, color: theme.colorScheme.primary),
          title: const Text('Domov'),
          onTap: () => Navigator.pop(context, 'home'),
        ),
        ListTile(
          leading: Icon(Icons.menu_book, color: theme.colorScheme.primary),
          title: const Text('Lectio divina'),
          onTap: () => Navigator.pop(context, 'lectio'),
        ),
        ListTile(
          leading: Icon(Icons.campaign, color: theme.colorScheme.primary),
          title: const Text('Aktuality'),
          onTap: () => Navigator.pop(context, 'news'),
        ),
        ListTile(
          leading: Icon(Icons.settings, color: theme.colorScheme.primary),
          title: const Text('Nastavenia'),
          onTap: () => Navigator.pop(context, 'settings'),
        ),
        const Divider(),
        ListTile(
          leading: Icon(getAuthIcon(), color: getAuthColor(theme)),
          title: Text(getAuthLabel()),
          onTap: () => Navigator.pop(context, 'auth'),
        ),
      ],
    );
  }
}
