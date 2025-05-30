import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final supabase = Supabase.instance.client;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  bool isLogin = true;
  Session? session;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    session = supabase.auth.currentSession;
    supabase.auth.onAuthStateChange.listen((_) {
      setState(() {
        session = supabase.auth.currentSession;
      });
    });
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final fullName = fullNameController.text.trim();

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        final userId = response.user?.id;
        if (userId != null && fullName.isNotEmpty) {
          await supabase.from('users').insert({
            'id': userId,
            'full_name': fullName,
            'is_active': true,
          });
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() => errorMessage = e.message);
    }
  }

  void enterWithoutLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = session?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Lectio Divina')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: user == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Heslo'),
                  ),
                  if (!isLogin)
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(labelText: 'Meno'),
                    ),
                  const SizedBox(height: 16),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ElevatedButton(
                    onPressed: handleAuth,
                    child: Text(isLogin ? 'Prihlásiť sa' : 'Registrovať sa'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? 'Nemáte účet? Registrovať sa'
                          : 'Máte účet? Prihlásiť sa',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: enterWithoutLogin,
                    child: const Text('Pokračovať bez prihlásenia'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Meno: \${user.userMetadata?['full_name'] ?? '-'}"),
                  Text("Email: \${user.email ?? '-'}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: signOut,
                    child: const Text("Odhlásiť sa"),
                  ),
                ],
              ),
      ),
    );
  }
}
