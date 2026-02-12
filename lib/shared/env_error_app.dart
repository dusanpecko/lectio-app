import 'package:flutter/material.dart';
import 'package:lectio_divina/shared/app_theme.dart';
import 'app_spacing.dart';

class EnvErrorApp extends StatelessWidget {
  const EnvErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lectio Divina - Config Error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Konfigurácia chýba / Missing config'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'Chýba konfigurácia / Missing configuration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'V súbore .env chýbajú kľúče SUPABASE_URL alebo SUPABASE_ANON_KEY.\n\n'
                    'Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
