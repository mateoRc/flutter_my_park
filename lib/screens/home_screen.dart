import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);

    return sessionAsync.when(
      data: (session) {
        final user = session?.user;
        final email = user?.email ?? '';
        final isHost = user?.userMetadata?['is_host'] == true;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
            actions: [
              IconButton(
                tooltip: 'Log out',
                onPressed: () async {
                  await ref.read(supabaseClientProvider).auth.signOut();
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
                  'Signed in as\n$email',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text(isHost ? 'Host' : 'Guest'),
                  avatar: Icon(
                    isHost ? Icons.workspace_premium : Icons.person,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/spots/map'),
                      icon: const Icon(Icons.map),
                      label: const Text('Browse map'),
                    ),
                    if (isHost)
                      FilledButton.icon(
                        onPressed: () => context.go('/host/spots'),
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text('Manage my spots'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Expanded(child: SpotSearchPanel()),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Session error: $error')),
      ),
    );
  }
}

class SpotSearchPanel extends ConsumerStatefulWidget {
  const SpotSearchPanel({super.key});

  @override
  ConsumerState<SpotSearchPanel> createState() => _SpotSearchPanelState();
}

class _SpotSearchPanelState extends ConsumerState<SpotSearchPanel> {
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

    final repository = ref.read(spotRepositoryProvider);
    try {
      final results = await repository.getNearby(
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
    return Column(
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
                      onTap: () => context.push('/spots/${spot.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
