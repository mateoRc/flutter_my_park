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

  late final MapController _mapController;
  MapQuery? _query;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueryFromMap();
    });
  }

  void _updateQueryFromMap() {
    final center = _mapController.center;
    final zoom = _mapController.zoom;
    final radius = _approxVisibleRadiusMeters(zoom);
    setState(() {
      _query = MapQuery(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: radius,
      );
    });
  }

  double _approxVisibleRadiusMeters(double zoom) {
    // Rough heuristic: radius halves when zoom increments by 1
    const baseRadius = 1200.0; // at zoom 14
    final exponent = _defaultZoom - zoom;
    return baseRadius * math.pow(2, exponent).clamp(0.5, 8.0);
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
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: _defaultZoom,
                onMapReady: () => _updateQueryFromMap(),
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
          ),
          if (spotsAsync.hasValue)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${spotsAsync.value!.length} spot(s) in view',
                style: Theme.of(context).textTheme.bodyMedium,
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
      onTap: () => context.push('/spots/${spot.id}') ,
      child: const Icon(
        Icons.location_on,
        color: Colors.redAccent,
        size: 32,
      ),
    );
  }
}
