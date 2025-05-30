import 'package:flutter/material.dart';

class LectioScreen extends StatelessWidget {
  const LectioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectio Divina – Lectio'),
      ),
      body: const Center(
        child: Text(
          'Tu bude obsah Lectio Divina modulu',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
