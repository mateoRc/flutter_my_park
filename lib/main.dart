import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'EXPO_PUBLIC_SUPABASE_URL',
  defaultValue: 'https://your-project.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'EXPO_PUBLIC_SUPABASE_KEY',
  defaultValue: 'public-anon-key',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;
  Session? _session;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _authSub = auth.onAuthStateChange.listen((data) {
      setState(() {
        _session = data.session;
      });
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null && session.user != null) {
      return HomePage(email: session.user?.email ?? '');
    }
    return const AuthFlow();
  }
}

enum AuthAction { signIn, signUp }

class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supabase Auth'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Log in'),
              Tab(text: 'Register'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AuthForm(action: AuthAction.signIn),
            AuthForm(action: AuthAction.signUp),
          ],
        ),
      ),
    );
  }
}

class AuthForm extends StatefulWidget {
  const AuthForm({super.key, required this.action});

  final AuthAction action;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  OAuthProvider? _oauthInProgress;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in both fields.');
      return;
    }

    setState(() => _isLoading = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (widget.action == AuthAction.signIn) {
        await auth.signInWithPassword(email: email, password: password);
      } else {
        final response = await auth.signUp(email: email, password: password);
        if (response.session == null) {
          _showMessage('Check your inbox to confirm registration.');
        }
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Unexpected error: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() => _oauthInProgress = provider);
    final auth = Supabase.instance.client.auth;
    try {
      final redirect = Uri.base.origin;
      await auth.signInWithOAuth(provider, redirectTo: redirect);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Unexpected error: $error');
    } finally {
      if (mounted) {
        setState(() => _oauthInProgress = null);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.action == AuthAction.signIn;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLogin ? 'Log in' : 'Register'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Or continue with'),
              const SizedBox(height: 16),
              _OAuthButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                isLoading: _oauthInProgress == OAuthProvider.google,
                onPressed: _oauthInProgress == null
                    ? () => _signInWithProvider(OAuthProvider.google)
                    : null,
              ),
              const SizedBox(height: 12),
              _OAuthButton(
                label: 'Continue with Facebook',
                icon: Icons.facebook,
                isLoading: _oauthInProgress == OAuthProvider.facebook,
                onPressed: _oauthInProgress == null
                    ? () => _signInWithProvider(OAuthProvider.facebook)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Signed in as\n$email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
