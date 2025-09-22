import '../models/favorite.dart';

abstract class FavoriteRepository {
  Future<Favorite> addFavorite({required String userId, required String spotId});
  Future<void> removeFavorite({required String userId, required String spotId});
  Future<List<Favorite>> listFavorites(String userId);
}
