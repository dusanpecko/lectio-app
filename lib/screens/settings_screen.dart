import 'package:flutter/material.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';

String fabMenuPositionLabel(FabMenuPosition pos) {
  switch (pos) {
    case FabMenuPosition.right:
      return "Vpravo dole";
    case FabMenuPosition.left:
      return "Vľavo dole";
    case FabMenuPosition.center:
      return "Uprostred dole";
    case FabMenuPosition.topLeft:
      return "Vľavo hore";
    case FabMenuPosition.topRight:
      return "Vpravo hore";
    case FabMenuPosition.topCenter:
      return "Uprostred hore";
    default:
      return "Vpravo dole";
  }
}

class SettingsScreen extends StatefulWidget {
  final FabMenuPosition currentPosition;
  final ValueChanged<FabMenuPosition> onPositionChanged;

  const SettingsScreen({
    Key? key,
    required this.currentPosition,
    required this.onPositionChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late FabMenuPosition _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.currentPosition;
  }

  void _onPositionChanged(FabMenuPosition? pos) {
    if (pos == null) return;
    setState(() {
      _selectedPosition = pos;
    });
    widget.onPositionChanged(pos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavenia'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Nastavenie polohy menu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<FabMenuPosition>(
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

          // Tu pridaj ďalšie nastavenia do budúcna...
          const Text(
            'Ďalšie nastavenia pripravujeme...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
