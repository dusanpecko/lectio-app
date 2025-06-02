import 'package:flutter/material.dart';
import '../shared/fab_menu_position.dart';

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
      default:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _getAlignment(),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: FloatingActionButton(
          foregroundColor: Colors.white,
          backgroundColor: Colors.deepPurple,
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              builder: (context) => _buildMenu(context),
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            );
            if (result != null) onTap(result);
          },
          child: const Icon(Icons.menu),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Domov'),
          onTap: () => Navigator.pop(context, 'home'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Nastavenia'),
          onTap: () => Navigator.pop(context, 'settings'),
        ),
        // Pridaj ďalšie položky podľa potreby
      ],
    );
  }
}
