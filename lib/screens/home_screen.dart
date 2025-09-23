import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const _defaultCenter = LatLng(45.8150, 15.9819);
  static const _defaultRadius = 1000.0;
  static const _defaultZoom = 14.0;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late MapQuery _mapQuery;

  @override
  void initState() {
    super.initState();
    _mapQuery = MapQuery(
      latitude: HomeScreen._defaultCenter.latitude,
      longitude: HomeScreen._defaultCenter.longitude,
      radiusMeters: HomeScreen._defaultRadius,
    );
  }

  void _updateMapQuery(MapQuery query) {
    setState(() => _mapQuery = query);
  }

  @override
  Widget build(BuildContext context) {
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
                  'Signed in as\\n$email',
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
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/spots/map'),
                      icon: const Icon(Icons.map),
                      label: const Text('Browse map'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/bookings'),
                      icon: const Icon(Icons.event_note),
                      label: const Text('My bookings'),
                    ),
                    if (isHost) ...[
                      FilledButton.icon(
                        onPressed: () => context.go('/host/spots'),
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text('Manage my spots'),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go('/host/bookings'),
                        icon: const Icon(Icons.view_list),
                        label: const Text('Spot bookings'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                MiniMapPreview(query: _mapQuery),
                const SizedBox(height: 24),
                Expanded(
                  child: SpotSearchPanel(
                    initialQuery: _mapQuery,
                    onQueryChanged: _updateMapQuery,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Session error: ')),
      ),
    );
  }
}

class MiniMapPreview extends ConsumerWidget {
  const MiniMapPreview({
    super.key,
    required this.query,
  });

  final MapQuery query;

  double _zoomForRadius(double radius) {
    const baseRadius = HomeScreen._defaultRadius;
    final exponent = math.log(radius / baseRadius) / math.log(2);
    final zoom = HomeScreen._defaultZoom - exponent;
    return zoom.clamp(3.0, 18.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(mapSpotsProvider(query));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 420.0);
        final height = width * 1.1;
        final center = LatLng(query.latitude, query.longitude);
        final zoom = _zoomForRadius(query.radiusMeters);
        final mapKey =
            ValueKey('::');

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    FlutterMap(
                      key: mapKey,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: zoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.flutter_my_park',
                        ),
                        spotsAsync.when(
                          data: (spots) => MarkerLayer(
                            markers: spots
                                .map(
                                  (spot) => Marker(
                                    point: LatLng(spot.lat, spot.lng),
                                    width: 32,
                                    height: 32,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.redAccent,
                                      size: 28,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          error: (_, __) => const MarkerLayer(markers: []),
                          loading: () => const MarkerLayer(markers: []),
                        ),
                      ],
                    ),
                    if (spotsAsync.hasError)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Spots failed to load: ',
                                style: const TextStyle(color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              spotsAsync.maybeWhen(
                                    data: (spots) => ' spot(s) nearby',
                                    orElse: () => 'Use gestures to explore',
                                  ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.go('/spots/map'),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Open full map'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SpotSearchPanel extends ConsumerStatefulWidget {
  const SpotSearchPanel({
    super.key,
    required this.initialQuery,
    required this.onQueryChanged,
  });

  final MapQuery initialQuery;
  final ValueChanged<MapQuery> onQueryChanged;

  @override
  ConsumerState<SpotSearchPanel> createState() => _SpotSearchPanelState();
}

class _SpotSearchPanelState extends ConsumerState<SpotSearchPanel> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;

  bool _searching = false;
  List<Spot> _spots = const [];
  String? _error;
  MapQuery? _lastAppliedQuery;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.initialQuery.latitude.toStringAsFixed(4),
    );
    _lngController = TextEditingController(
      text: widget.initialQuery.longitude.toStringAsFixed(4),
    );
    _radiusController = TextEditingController(
      text: widget.initialQuery.radiusMeters.toStringAsFixed(0),
    );
    _lastAppliedQuery = widget.initialQuery;
  }

  @override
  void didUpdateWidget(covariant SpotSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastAppliedQuery == null ||
        widget.initialQuery.latitude != _lastAppliedQuery!.latitude ||
        widget.initialQuery.longitude != _lastAppliedQuery!.longitude ||
        widget.initialQuery.radiusMeters != _lastAppliedQuery!.radiusMeters) {
      _latController.text = widget.initialQuery.latitude.toStringAsFixed(4);
      _lngController.text = widget.initialQuery.longitude.toStringAsFixed(4);
      _radiusController.text = widget.initialQuery.radiusMeters.toStringAsFixed(0);
      _lastAppliedQuery = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());
    if (lat == null || lng == null || radius == null) {
      setState(() => _error = 'Enter valid latitude, longitude, and radius.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    final repository = ref.read(spotRepositoryProvider);
    final query = MapQuery(
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
    );

    try {
      final results = await repository.getNearby(
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
      );
      if (!mounted) return;
      setState(() {
        _spots = results;
        _lastAppliedQuery = query;
      });
      widget.onQueryChanged(query);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Search failed: ');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
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
                        'Lat , '
                        'Lng ',
                      ),
                      trailing: spot.priceHour != null
                          ? Text('EUR /h')
                          : null,
                      onTap: () => context.push('/spots/'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}





