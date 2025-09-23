import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../providers.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _LoginAppBar(),
        body: TabBarView(
          children: [
            _AuthForm(action: _AuthAction.signIn),
            _AuthForm(action: _AuthAction.signUp),
          ],
        ),
      ),
    );
  }
}

class _LoginAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LoginAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Supabase Auth'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Log in'),
          Tab(text: 'Register'),
        ],
      ),
    );
  }
}

enum _AuthAction { signIn, signUp }

class _AuthForm extends ConsumerStatefulWidget {
  const _AuthForm({required this.action});

  final _AuthAction action;

  @override
  ConsumerState<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<_AuthForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isHost = false;
  OAuthProvider? _oauthInProgress;

  bool get _isRegister => widget.action == _AuthAction.signUp;

  GoTrueClient get _auth => ref.read(supabaseClientProvider).auth;

  Future<void> _ensureProfileExists(User user) async {
    final repository = ref.read(profileRepositoryProvider);
    final existing = await repository.getProfile(user.id);
    if (existing != null) {
      return;
    }

    await repository.updateProfile(
      Profile(
        id: user.id,
        name: user.userMetadata?['full_name'] as String? ?? user.email,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

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
      _showMessage('Please fill in both email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.action == _AuthAction.signIn) {
        final response = await _auth.signInWithPassword(
          email: email,
          password: password,
        );

        final session = response.session;
        final user = response.user;
        if (session != null && user != null) {
          await _ensureProfileExists(user);

          final metadata = user.userMetadata ?? const <String, dynamic>{};
          final isHostUser = metadata['is_host'] == true;
          final needsProfile = metadata['needs_profile'] == true;
          if (isHostUser && needsProfile && mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                const SnackBar(content: Text('Let\'s finish your host profile.')),
              );
            context.go('/profile');
          }
        }
      } else {
        final response = await _auth.signUp(
          email: email,
          password: password,
          data: {
            'is_host': _isHost,
            if (_isHost) 'needs_profile': true,
          },
        );

        final session = response.session;
        final user = response.user;

        if (_isHost) {
          if (session != null && user != null) {
            await _ensureProfileExists(user);
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(content: Text('Welcome! Let\'s finish your host profile.')),
                );
              context.go('/profile');
            }
          } else {
            _showMessage(
              'Check your inbox to confirm registration. Once verified, sign in and complete your host profile.',
            );
          }
        } else if (session == null) {
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
    try {
      final redirect = Uri.base.origin;
      await _auth.signInWithOAuth(provider, redirectTo: redirect);
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
    final isLogin = widget.action == _AuthAction.signIn;
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
              if (_isRegister) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _isHost,
                  onChanged: (value) => setState(() => _isHost = value),
                  title: const Text('Register as a host'),
                  subtitle: const Text('Hosts can create and manage parking spots.'),
                ),
              ],
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
              if (isLogin)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Hosts are recognised automatically from their profile metadata.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
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
