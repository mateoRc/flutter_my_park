import '../models/spot.dart';

abstract class SpotRepository {
  Future<List<Spot>> getNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000,
  });
  Future<Spot> createSpot(Spot spot);
  Future<Spot> updateSpot(Spot spot);
  Future<void> deleteSpot(String id);
}
