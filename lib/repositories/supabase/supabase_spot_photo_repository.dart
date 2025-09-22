import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/spot_photo.dart';
import '../spot_photo_repository.dart';

class SupabaseSpotPhotoRepository implements SpotPhotoRepository {
  SupabaseSpotPhotoRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'spot-photos';
  static const _table = 'spot_photos';

  StorageFileApi get _storage => _client.storage.from(_bucket);

  @override
  Future<List<SpotPhoto>> listSpotPhotos(String spotId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('spot_id', spotId)
        .order('order', ascending: true);

    return (response as List<dynamic>)
        .map((row) => SpotPhoto.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<SpotPhoto> uploadSpotPhoto({
    required String spotId,
    required String path,
    required Uint8List bytes,
    required int order,
    String? contentType,
  }) async {
    await _storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType,
      ),
    );

    final inserted = await _client
        .from(_table)
        .upsert({
          'spot_id': spotId,
          'path': path,
          'order': order,
        })
        .select()
        .single();

    return SpotPhoto.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<void> deleteSpotPhoto(String spotId, String path) async {
    await _storage.remove([path]);
    await _client
        .from(_table)
        .delete()
        .match({'spot_id': spotId, 'path': path});
  }
}
