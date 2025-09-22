import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/spot.dart';
import '../spot_repository.dart';
import 'rpc_invoker.dart';

class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository({
    SupabaseClient? client,
    RpcInvoker? rpc,
  })  : _client = client ?? Supabase.instance.client,
        _rpc = rpc ??
            ((fn, {params}) => (client ?? Supabase.instance.client)
                .rpc(fn, params: params));

  final SupabaseClient _client;
  final RpcInvoker _rpc;

  static const _table = 'spots';
  static const _rpcName = 'spots_nearby';

  @override
  Future<List<Spot>> getNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000,
  }) async {
    final response = await _rpc(
      _rpcName,
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
  Future<List<Spot>> listOwned({required String ownerId}) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => Spot.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<Spot?> getSpot(String id) async {
    final result = await _client.from(_table).select().eq('id', id).maybeSingle();
    if (result == null) {
      return null;
    }
    return Spot.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<Spot> createSpot(Spot spot) async {
    final inserted = await _client
        .from(_table)
        .insert(spot.toJson())
        .select()
        .single();
    return Spot.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<Spot> updateSpot(Spot spot) async {
    final updated = await _client
        .from(_table)
        .update(spot.toJson())
        .eq('id', spot.id)
        .select()
        .single();
    return Spot.fromJson(Map<String, dynamic>.from(updated));
  }

  @override
  Future<void> deleteSpot(String id) {
    return _client.from(_table).delete().eq('id', id);
  }
}
