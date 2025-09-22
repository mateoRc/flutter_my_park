import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/models.dart';
import 'repositories/repositories.dart';
import 'repositories/supabase/supabase_repositories.dart';

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
      final user = session.user!;
      final isHost = user.userMetadata?['is_host'] == true;
      return HomePage(
        email: user.email ?? '',
        isHost: isHost,
      );
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
  bool _isHost = false;
  OAuthProvider? _oauthInProgress;

  bool get _isRegister => widget.action == AuthAction.signUp;

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
    final auth = Supabase.instance.client.auth;
    try {
      if (widget.action == AuthAction.signIn) {
        await auth.signInWithPassword(email: email, password: password);
      } else {
        final response = await auth.signUp(
          email: email,
          password: password,
          data: {'is_host': _isHost},
        );
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

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.email, required this.isHost});

  final String email;
  final bool isHost;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpotRepository _spotRepository = SupabaseSpotRepository();

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.isHost ? 'Host' : 'Guest';
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in as\n${widget.email}',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(roleLabel),
              avatar: Icon(
                widget.isHost ? Icons.workspace_premium : Icons.person,
                size: 18,
              ),
            ),
            const SizedBox(height: 24),
            SpotSearchPanel(repository: _spotRepository),
          ],
        ),
      ),
    );
  }
}

class SpotSearchPanel extends StatefulWidget {
  const SpotSearchPanel({super.key, required this.repository});

  final SpotRepository repository;

  @override
  State<SpotSearchPanel> createState() => _SpotSearchPanelState();
}

class _SpotSearchPanelState extends State<SpotSearchPanel> {
  final _latController = TextEditingController(text: '45.8150');
  final _lngController = TextEditingController(text: '15.9819');
  final _radiusController = TextEditingController(text: '1000');
  bool _searching = false;
  List<Spot> _spots = const [];
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    final radius = double.tryParse(_radiusController.text);
    if (lat == null || lng == null || radius == null) {
      setState(() => _error = 'Enter valid latitude, longitude, and radius.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await widget.repository.getNearby(
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
      );
      if (!mounted) return;
      setState(() => _spots = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Search failed: $error');
    } finally {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find nearby spots',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _radiusController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Radius (meters)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Search'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _spots.isEmpty
                ? const Center(child: Text('No spots in range yet.'))
                : ListView.separated(
                    itemCount: _spots.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final spot = _spots[index];
                      return ListTile(
                        title: Text(spot.title),
                        subtitle: Text(
                          'Lat ${spot.lat.toStringAsFixed(4)}, '
                          'Lng ${spot.lng.toStringAsFixed(4)}',
                        ),
                        trailing: spot.priceHour != null
                            ? Text('€${spot.priceHour!.toStringAsFixed(2)}/h')
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
