import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';
import '../providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _defaultCenter = LatLng(45.8150, 15.9819);
  static const _defaultZoom = 14.0;
  static const _defaultRadiusMeters = 10000.0;

  late final MapController _mapController;
  MapQuery? _query;
  double? _requestedRadiusMeters;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _latController = TextEditingController(text: _defaultCenter.latitude.toStringAsFixed(4));
    _lngController = TextEditingController(text: _defaultCenter.longitude.toStringAsFixed(4));
    _radiusController = TextEditingController(text: _defaultRadiusMeters.toStringAsFixed(0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueryFromMap();
    });
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _setQuery(MapQuery query) {
    setState(() {
      _query = query;
    });
  }

  void _updateQueryFromMap() {
    final center = _mapController.center;
    final zoom = _mapController.zoom;
    final radius = _requestedRadiusMeters ?? _approxVisibleRadiusMeters(zoom);
    _setQuery(
      MapQuery(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: radius,
      ),
    );
  }

  double _approxVisibleRadiusMeters(double zoom) {
    const baseRadius = 1200.0; // at zoom 14
    final exponent = _defaultZoom - zoom;
    final factor = math.pow(2, exponent).clamp(0.5, 8.0) as num;
    return baseRadius * factor.toDouble();
  }

  double _zoomForRadius(double radius) {
    const baseRadius = 1200.0;
    final exponent = math.log(radius / baseRadius) / math.log(2);
    final zoom = _defaultZoom - exponent;
    return zoom.clamp(3.0, 18.0);
  }

  Future<void> _applySearch() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());
    if (lat == null || lng == null || radius == null) {
      setState(() => _searchError = 'Enter valid latitude, longitude, and radius.');
      return;
    }

    setState(() {
      _searchError = null;
      _requestedRadiusMeters = radius;
    });

    final target = LatLng(lat, lng);
    final zoom = _zoomForRadius(radius);
    _mapController.move(target, zoom);
    _setQuery(
      MapQuery(
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
      ),
    );
  }

  void _resetSearch() {
    _latController.text = _defaultCenter.latitude.toStringAsFixed(4);
    _lngController.text = _defaultCenter.longitude.toStringAsFixed(4);
    _radiusController.text = _defaultRadiusMeters.toStringAsFixed(0);
    setState(() {
      _requestedRadiusMeters = null;
      _searchError = null;
    });
    _mapController.move(_defaultCenter, _defaultZoom);
    _setQuery(
      MapQuery(
        latitude: _defaultCenter.latitude,
        longitude: _defaultCenter.longitude,
        radiusMeters: _defaultRadiusMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final spotsAsync = query == null
        ? const AsyncValue<List<Spot>>.loading()
        : ref.watch(mapSpotsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spots map'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              onMapReady: _updateQueryFromMap,
              onPositionChanged: (_, __) => _updateQueryFromMap(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_my_park',
              ),
              spotsAsync.when(
                loading: () => const MarkerLayer(markers: []),
                error: (error, stack) => MarkerLayer(
                  markers: [
                    Marker(
                      point: _mapController.center,
                      width: 200,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Tooltip(
                        message: 'Failed to load: $error',
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ],
                ),
                data: (spots) => MarkerLayer(
                  markers: spots
                      .map(
                        (spot) => Marker(
                          point: LatLng(spot.lat, spot.lng),
                          width: 40,
                          height: 40,
                          child: _SpotMarker(spot: spot),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search map',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _latController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Latitude'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _lngController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Longitude'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _radiusController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Radius (meters)',
                            ),
                          ),
                          if (_searchError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _searchError!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _applySearch,
                                icon: const Icon(Icons.search),
                                label: const Text('Apply'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _resetSearch,
                                child: const Text('Reset'),
                              ),
                              const Spacer(),
                              if (query != null)
                                Text(
                                  '${query.radiusMeters.round()} m radius',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (spotsAsync.hasValue)
            Positioned(
              bottom: 16,
              left: 16,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    '${spotsAsync.value!.length} spot(s) in view',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotMarker extends StatelessWidget {
  const _SpotMarker({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/spots/${spot.id}'),
      child: const Icon(
        Icons.location_on,
        color: Colors.redAccent,
        size: 32,
      ),
    );
  }
}
