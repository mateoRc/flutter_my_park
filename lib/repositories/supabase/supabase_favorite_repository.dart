import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/favorite.dart';
import '../favorite_repository.dart';

class SupabaseFavoriteRepository implements FavoriteRepository {
  SupabaseFavoriteRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'favorites';

  @override
  Future<Favorite> addFavorite({
    required String userId,
    required String spotId,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'spot_id': spotId,
    };
    final inserted = await _client
        .from(_table)
        .upsert(payload)
        .select()
        .single();
    return Favorite.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String spotId,
  }) {
    return _client
        .from(_table)
        .delete()
        .match({'user_id': userId, 'spot_id': spotId});
  }

  @override
  Future<List<Favorite>> listFavorites(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((row) => Favorite.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }
}
