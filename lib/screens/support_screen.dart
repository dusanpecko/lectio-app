import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podporte')),
      body: const Center(
        child: Text('Obsah čoskoro...', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
