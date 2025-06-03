import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool _showResetPassword = false;
  final _resetEmailController = TextEditingController();
  String? _resetInfo;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _resetEmailController.dispose();
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
      if (response.session == null) {
        setState(() {
          _error = tr('wrong_credentials');
        });
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (e is AuthApiException && e.statusCode == 400) {
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
      if (response.user == null) {
        setState(() {
          _error = tr('register_failed');
        });
      } else {
        // Vlož používateľa do vlastnej tabuľky users
        final userId = response.user!.id;
        await Supabase.instance.client.from('users').insert({
          'id': userId,
          'full_name': fullName,
          'email': email,
        });
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthApiException catch (e) {
      if (e.statusCode == 400 &&
          e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = tr('user_exists');
        });
      } else if (e.statusCode == 400 &&
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
      setState(() {
        _error = tr('register_failed_retry');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      setState(() {
        _resetInfo = tr('reset_email_sent');
      });
    } on AuthApiException catch (e) {
      setState(() {
        _resetInfo = e.message;
      });
    } catch (e) {
      setState(() {
        _resetInfo = tr('something_went_wrong');
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
        Text(
          tr('reset_password_title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _resetEmailController,
          decoration: InputDecoration(labelText: tr('email')),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 24),
        if (_resetInfo != null)
          Text(
            _resetInfo!,
            style: TextStyle(
              color: _resetInfo == tr('reset_email_sent')
                  ? Colors.green
                  : Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('reset_password')),
          ),
        ),
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
