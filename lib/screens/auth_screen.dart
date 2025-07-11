// auth_screen.dart - KOMPLETNE OPRAVENÁ VERZIA
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
// ODSTRÁNENÝ IMPORT: import 'reset_password_screen.dart';
import 'package:uni_links/uni_links.dart';

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
  bool _showResetPassword = false;
  final _resetEmailController = TextEditingController();
  String? _resetInfo;

  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initUniLinks();

    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  Future<void> _initUniLinks() async {
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      // Handle exception, ak treba
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'lectio_divina' && uri.host == 'reset-password') {
      final accessToken = uri.queryParameters['access_token'];
      if (accessToken != null) {
        // DOČASNE ODSTRÁNENÉ - len debug print
        print('Reset password deep link received with token: $accessToken');
        // Navigator.of(context).push(
        //   MaterialPageRoute(
        //     builder: (_) => ResetPasswordScreen(accessToken: accessToken),
        //   ),
        // );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _resetEmailController.dispose();
    _sub?.cancel();
    super.dispose();
  }

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
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _error = tr('wrong_credentials');
        });
      } else {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AuthApiException && e.statusCode == '400') {
        // String namiesto int
        setState(() {
          _error = tr('wrong_credentials');
        });
      } else if (e is AuthApiException &&
          e.message.toLowerCase().contains('email not confirmed')) {
        setState(() {
          _error = tr('email_not_confirmed');
        });
      } else {
        setState(() {
          _error = tr('login_failed');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (fullName.isEmpty) {
        setState(() {
          _error = tr('name_required');
          _isLoading = false;
        });
        return;
      }
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (response.user == null) {
        setState(() {
          _error = tr('register_failed');
        });
      } else {
        final userId = response.user!.id;
        await Supabase.instance.client.from('users').insert({
          'id': userId,
          'full_name': fullName,
          'email': email,
        });
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == '400' && // String namiesto int
          e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = tr('user_exists');
        });
      } else if (e.statusCode == '400' && // String namiesto int
          e.message.toLowerCase().contains('password should be')) {
        setState(() {
          _error = tr('password_length');
        });
      } else {
        setState(() {
          _error = tr('register_failed_try_other');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = tr('register_failed_retry');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _resetInfo = null;
    });
    try {
      final email = _resetEmailController.text.trim();
      if (email.isEmpty) {
        setState(() {
          _resetInfo = tr('email_required');
          _isLoading = false;
        });
        return;
      }

      // ZMEŇTE URL na váš web domain:
      const webResetUrl = 'http://localhost:3000/auth/reset-password';
      // Pre produkciu zmeňte na:
      // 'https://yourdomain.com/auth/reset-password'
      // 'https://lectio-divina.vercel.app/auth/reset-password'

      print(
        'Sending reset email to: $email with redirect: $webResetUrl',
      ); // Debug log

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: webResetUrl,
      );

      if (!mounted) return;
      setState(() {
        _resetInfo = tr('reset_email_sent');
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resetInfo = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resetInfo = tr('something_went_wrong');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      appBar: AppBar(title: Text(_isRegister ? tr('register') : tr('login'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _showResetPassword
              ? _buildResetPassword(context)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRegister)
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(labelText: tr('name')),
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                      ),
                    if (_isRegister) const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: tr('email')),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: tr('password')),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isRegister ? tr('register') : tr('login')),
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
                        _isRegister ? tr('have_account') : tr('no_account'),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _showResetPassword = true;
                                  _resetEmailController.text =
                                      _emailController.text;
                                  _resetInfo = null;
                                });
                              },
                        child: Text(tr('forgot_password')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _continueAsGuest,
                        child: Text(tr('continue_without_login')),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResetPassword(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ikona
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).primaryColor.withValues(alpha: 0.1), // Opravené withValues
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset,
            size: 40,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr('reset_password_title'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Zadajte svoj email a pošleme vám odkaz na obnovenie hesla na webovej stránke.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _resetEmailController,
          decoration: InputDecoration(
            labelText: tr('email'),
            hintText: tr('email'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 24),
        if (_resetInfo != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _resetInfo == tr('reset_email_sent')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              border: Border.all(
                color: _resetInfo == tr('reset_email_sent')
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _resetInfo == tr('reset_email_sent')
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: _resetInfo == tr('reset_email_sent')
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resetInfo!,
                        style: TextStyle(
                          color: _resetInfo == tr('reset_email_sent')
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                        ),
                      ),
                      if (_resetInfo == tr('reset_email_sent')) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kliknite na odkaz v emaili ihneď (platnosť 1 hodina), zmeňte heslo na webovej stránke a potom sa vráťte do aplikácie.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    tr('reset_password'),
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _showResetPassword = false;
                  });
                },
          child: Text(tr('back_to_login')),
        ),
      ],
    );
  }
}
