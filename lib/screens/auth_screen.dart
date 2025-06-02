import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isRegister = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (response.session == null) {
        setState(() {
          _error = 'Nesprávny email alebo heslo.';
        });
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Ošetríme "invalid_credentials" a ostatné chyby
      if (e is AuthApiException && e.statusCode == 400) {
        setState(() {
          _error = 'Nesprávny email alebo heslo.';
        });
      } else if (e is AuthApiException &&
          e.message.toLowerCase().contains('email not confirmed')) {
        setState(() {
          _error =
              'Emailová adresa nebola potvrdená. Skontrolujte si email a potvrďte registráciu.';
        });
      } else {
        setState(() {
          _error = 'Prihlásenie zlyhalo.';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fullName = _fullNameController.text.trim();
      if (fullName.isEmpty) {
        setState(() {
          _error = 'Zadajte meno';
          _isLoading = false;
        });
        return;
      }
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': fullName}, // uloží full_name do DB
      );
      if (response.user == null) {
        setState(() {
          _error = 'Registrácia zlyhala.';
        });
      } else {
        setState(() {
          _isRegister = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registrácia prebehla úspešne! Skontrolujte si email a potvrďte registráciu.',
            ),
          ),
        );
      }
    } on AuthApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = 'Používateľ s týmto emailom už existuje.';
        });
      } else if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('password should be')) {
        setState(() {
          _error = 'Heslo je príliš krátke alebo slabé.';
        });
      } else {
        setState(() {
          _error =
              'Registrácia zlyhala. Skúste iný email alebo silnejšie heslo.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Registrácia zlyhala. Skúste znova neskôr.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _continueAsGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Registrácia' : 'Prihlásenie')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRegister)
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Meno a priezvisko',
                  ),
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                ),
              if (_isRegister) const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Heslo'),
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _isRegister
                      ? _signUp
                      : _signIn,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegister ? 'Registrovať sa' : 'Prihlásiť sa'),
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isRegister = !_isRegister;
                          _error = null;
                        });
                      },
                child: Text(
                  _isRegister
                      ? 'Už mám účet. Prihlásiť sa'
                      : 'Nemáte účet? Registrovať sa',
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _continueAsGuest,
                  child: const Text('Pokračovať bez prihlásenia'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
