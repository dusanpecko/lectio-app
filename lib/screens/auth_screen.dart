import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/credentials_service.dart';
import '../utils/app_logger.dart';
import 'home_screen.dart';
import '../shared/app_spacing.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _credentialsService = CredentialsService();
  bool _isLoading = false;
  String? _error;
  bool _isRegister = false;
  bool _showResetPassword = false;
  bool _rememberMe = false;
  bool _newsletterConsent = false;
  bool _obscurePassword = true;
  final _resetEmailController = TextEditingController();
  String? _resetInfo;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final hasCredentials = await _credentialsService.hasCredentials();
      if (hasCredentials) {
        final credentials = await _credentialsService.getCredentials();
        setState(() {
          _emailController.text = credentials['email'] ?? '';
          _passwordController.text = credentials['password'] ?? '';
          _rememberMe = true;
        });
      }
    } catch (e) {
      appLogger.w('Failed to load saved credentials', error: e);
    }
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      appLogger.w('Failed to get initial app link', error: e);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        appLogger.w('Error listening to app links', error: err);
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    // Handle deep link

    // Handle Google OAuth callback - nový jednoduchší scheme
    if (uri.scheme == 'lectio-divina' && uri.host == 'login-callback') {
      // Google OAuth callback received
      // Supabase automaticky spracuje OAuth callback
      // Skontroluj či je používateľ prihlásený
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        // OAuth login successful, navigating to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }

    // Podpora pre staré schemes
    if ((uri.scheme == 'sk.lectio-divina.app' ||
            uri.scheme == 'lectio_divina') &&
        uri.host == 'login-callback') {
      // Google OAuth callback received (legacy)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        // OAuth login successful, navigating to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }

    // Handle password reset
    if (uri.scheme == 'lectio_divina' && uri.host == 'reset-password') {
      final accessToken = uri.queryParameters['access_token'];
      if (accessToken != null) {
        // Reset password deep link received with token
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _resetEmailController.dispose();
    _linkSubscription?.cancel();
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
        if (_rememberMe) {
          await _credentialsService.saveCredentials(
            _emailController.text.trim(),
            _passwordController.text,
          );
        } else {
          await _credentialsService.clearCredentials();
        }

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      appLogger.e('Sign in failed', error: e);
      if (!mounted) return;
      if (e is AuthApiException && e.statusCode == '400') {
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
          'newsletter_consent': _newsletterConsent,
        });

        if (_rememberMe) {
          await _credentialsService.saveCredentials(email, password);
        }

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthApiException catch (e) {
      appLogger.w('Sign up AuthApiException: ${e.statusCode}', error: e);
      if (!mounted) return;
      if (e.statusCode == '400' &&
          e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = tr('user_exists');
        });
      } else if (e.statusCode == '400' &&
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
      appLogger.e('Sign up failed', error: e);
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Starting Supabase Google OAuth with external application

      // Radikálne riešenie: späť na externe application ale s lepším callback
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'lectio-divina://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      // Supabase OAuth response logged

      if (!mounted) return;

      // Monitoruj zmeny v auth state s dlhším timeout
      _monitorAuthState();
    } catch (e) {
      appLogger.e('Google OAuth sign in failed', error: e);
      if (!mounted) return;
      setState(() {
        _error = '${tr('google_sign_in_error')}: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Generuje kryptograficky bezpečný náhodný nonce
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA256 hash nonce pre Apple
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Generuj nonce pre bezpečnosť
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // Natívny Apple Sign-In dialog
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple Sign-In: chýba identityToken');
      }

      // Prihlásenie cez Supabase s natívnym tokenom
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null && mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        appLogger.d('Apple sign in canceled by user');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      appLogger.w('Apple sign in authorization error', error: e);
      if (mounted) {
        setState(() {
          _error = '${tr('apple_sign_in_error')}: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      appLogger.e('Apple sign in failed', error: e);
      if (mounted) {
        setState(() {
          _error = '${tr('apple_sign_in_error')}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _monitorAuthState() {
    // Starting auth state monitoring
    late StreamSubscription<AuthState> subscription;

    // Kontrola aktuálnej session hneď na začiatku
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null && mounted) {
      // User already signed in, navigating to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // Auth state changed logged
      if (session != null) {
        // Session details logged
      }

      if (event == AuthChangeEvent.signedIn && session != null && mounted) {
        // User signed in via OAuth, navigating to home
        subscription.cancel(); // Zruš subscription

        // Malé oneskorenie pre stabilitu
        await Future.delayed(Duration(milliseconds: 300));

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Naviguj na domovskú obrazovku
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // User signed out
        subscription.cancel();
      }
    });

    // Dlhší timeout pre in-app browser
    Timer(Duration(seconds: 120), () {
      if (mounted) {
        subscription.cancel();
        setState(() {
          _isLoading = false;
          _error = tr('google_sign_in_timeout');
        });
        // Auth monitoring timeout after 120 seconds
      }
    });
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

      const webResetUrl = 'https://lectio.one/auth/reset-password';

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: webResetUrl,
      );

      if (!mounted) return;
      setState(() {
        _resetInfo = tr('reset_email_sent');
      });
    } on AuthApiException catch (e) {
      appLogger.w('Reset password AuthApiException', error: e);
      if (!mounted) return;
      setState(() {
        _resetInfo = e.message;
      });
    } catch (e) {
      appLogger.e('Reset password failed', error: e);
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

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? tr('register') : tr('login'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: _showResetPassword
              ? _buildResetPassword(context)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icon/lectio_logo.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (_isRegister)
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(labelText: tr('name')),
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                      ),
                    if (_isRegister) const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: tr('email')),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: tr('password'),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CheckboxListTile(
                      title: Text(tr('remember_me')),
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_isRegister)
                      CheckboxListTile(
                        title: Text(tr('newsletter_consent_label')),
                        value: _newsletterConsent,
                        onChanged: (value) {
                          setState(() {
                            _newsletterConsent = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Text(
                            tr('or'),
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Google Sign-In
                    _buildSocialButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Image.asset(
                        'assets/images/google_logo.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.g_mobiledata, size: 24);
                        },
                      ),
                      label: tr('sign_in_with_google'),
                      backgroundColor: Colors.white,
                      textColor: Colors.black87,
                      borderColor: Colors.grey.shade300,
                    ),
                    // Apple Sign-In (iOS / macOS only)
                    if (!Platform.isAndroid) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildSocialButton(
                        onPressed: _isLoading ? null : _signInWithApple,
                        icon: const Icon(
                          Icons.apple,
                          size: 22,
                          color: Colors.white,
                        ),
                        label: tr('sign_in_with_apple'),
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        borderColor: Colors.black,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _continueAsGuest,
                        child: Text(
                          tr('continue_without_login'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResetPassword(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset,
            size: 40,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          tr('reset_password_title'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Zadajte svoj email a pošleme vám odkaz na obnovenie hesla na webovej stránke.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
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
        const SizedBox(height: AppSpacing.xxl),
        if (_resetInfo != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _resetInfo == tr('reset_email_sent')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              border: Border.all(
                color: _resetInfo == tr('reset_email_sent')
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                const SizedBox(width: AppSpacing.sm),
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
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Kliknite na odkaz v emaili ihneď (platnosť 1 hodina), zmeňte heslo na webovej stránke a potom sa vráťte do aplikácie.',
                          style: theme.textTheme.bodySmall!.copyWith(
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
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    tr('reset_password'),
                    style: theme.textTheme.titleMedium,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
