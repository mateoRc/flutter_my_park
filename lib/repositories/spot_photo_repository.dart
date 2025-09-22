import 'dart:typed_data';

import '../models/spot_photo.dart';

abstract class SpotPhotoRepository {
  Future<List<SpotPhoto>> listSpotPhotos(String spotId);

  Future<SpotPhoto> uploadSpotPhoto({
    required String spotId,
    required String path,
    required Uint8List bytes,
    required int order,
    String? contentType,
  });

  Future<void> deleteSpotPhoto(String spotId, String path);
}
