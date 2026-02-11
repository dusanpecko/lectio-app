import 'dart:io';

import 'package:flutter/material.dart';

import '../services/do_not_disturb_service.dart';

/// Helper pre Do Not Disturb funkcionalitu v Lectio screen.
///
/// Obsahuje toggle logiku a iOS inštrukcie - extrahované z LectioScreen.
class DndHelper {
  DndHelper({
    required this.dndService,
    required this.context,
    required this.onStateChanged,
  });

  final DoNotDisturbService dndService;
  final BuildContext context;
  final void Function(bool isDndActive) onStateChanged;

  /// Toggle DND stav
  Future<void> handleDndToggle() async {
    try {
      if (dndService.isDndActive) {
        // Deaktivácia DND
        await dndService.deactivateDndManually();
      } else {
        // Aktivácia DND
        final hasPermissions = await dndService.checkPermissions();

        if (!hasPermissions) {
          final granted = await dndService.requestPermissions();
          if (!granted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pre aktiváciu Nerušiť je potrebné povoliť prístup k notifikáciám',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }

        // Aktivuj DND manuálne
        await dndService.activateDndManually();
      }

      // Aktualizuj UI stav
      onStateChanged(dndService.isDndActive);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.do_not_disturb_on, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isIOS
                        ? 'Zapnite "Nerušiť" manuálne v Control Center'
                        : 'Režim Nerušiť aktivovaný',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            action: Platform.isIOS
                ? SnackBarAction(
                    label: 'Ako na to',
                    textColor: Colors.white,
                    onPressed: () => showIOSDndInstructions(),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri prepínaní režimu Nerušiť: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zobrazí inštrukcie pre iOS DND
  void showIOSDndInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shortcut_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('iOS Shortcuts pre DND'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Automatické riešenie',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vytvorte si iOS Shortcuts pre automatické zapínanie/vypínanie Focus režimu pri používaní DND tlačidla.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildInstructionStep(
                '1',
                'Vytvorte Shortcuts',
                'Nastavenia → Vytvorte Shortcuts pre DND',
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                '2',
                'Použite DND tlačidlo',
                'Shortcuts sa spustia automaticky',
              ),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 12),

              Text(
                'Manuálne riešenie:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                'A',
                'Control Center',
                'Potiahnite zhora doprava → 🌙',
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                'B',
                'Focus režim',
                'Nastavenia → Focus → Do Not Disturb',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavrieť'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Nastavenia'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
