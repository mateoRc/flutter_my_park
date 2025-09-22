import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/spot.dart';
import '../spot_repository.dart';

class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _rpc = 'spots_nearby';

  @override
  Future<List<Spot>> getNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000,
  }) async {
    final response = await _client.rpc(
      _rpc,
      params: <String, dynamic>{
        'lat_input': latitude,
        'lng_input': longitude,
        'radius_m': radiusMeters,
      },
    );

    final rows = response as List<dynamic>?;
    if (rows == null) {
      return const [];
    }

    return rows
        .map((row) => Spot.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<Spot> createSpot(Spot spot) async {
    final inserted = await _client
        .from('spots')
        .insert(spot.toJson())
        .select()
        .single();
    return Spot.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<Spot> updateSpot(Spot spot) async {
    final updated = await _client
        .from('spots')
        .update(spot.toJson())
        .eq('id', spot.id)
        .select()
        .single();
    return Spot.fromJson(Map<String, dynamic>.from(updated));
  }

  @override
  Future<void> deleteSpot(String id) {
    return _client.from('spots').delete().eq('id', id);
  }
}
