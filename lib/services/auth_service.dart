import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._internal();

  static void setInstanceForTesting(AuthService service) {
    _instance = service;
  }

  final SupabaseClient _client;

  AuthService._internal({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // Sign In with Email and Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign Up with Email, Password, and Full Name
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Create user profile in users table
      await _client.from('users').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'email': email,
      });
    }

    return response;
  }

  // Reset Password
  Future<void> resetPassword({
    required String email,
    required String redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  // Sign In with Google
  Future<bool> signInWithGoogle({
    required String redirectTo,
  }) async {
    try {
      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign In with Apple
  Future<bool> signInWithApple({
    required String redirectTo,
  }) async {
    try {
      return await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Get Current Session
  Session? get currentSession => _client.auth.currentSession;

  // Stream Auth State
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
