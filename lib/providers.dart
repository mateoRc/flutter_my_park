import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/spot.dart';
import 'models/spot_photo.dart';
import 'repositories/booking_repository.dart';
import 'repositories/spot_photo_repository.dart';
import 'repositories/spot_repository.dart';
import 'repositories/supabase/supabase_booking_repository.dart';
import 'repositories/supabase/supabase_spot_photo_repository.dart';
import 'repositories/supabase/supabase_spot_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class RouteAuthNotifier extends ChangeNotifier {
  RouteAuthNotifier(this._auth) {
    _sub = _auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final GoTrueClient _auth;
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routeAuthNotifierProvider = Provider<RouteAuthNotifier>((ref) {
  final notifier = RouteAuthNotifier(ref.watch(supabaseClientProvider).auth);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final sessionProvider = StreamProvider<Session?>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;
  final controller = StreamController<Session?>();
  controller.add(auth.currentSession);
  final sub = auth.onAuthStateChange.listen((event) {
    controller.add(event.session);
  });
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSpotRepository(client: client);
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseBookingRepository(client: client);
});

final spotPhotoRepositoryProvider = Provider<SpotPhotoRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSpotPhotoRepository(client: client);
});

final hostSpotsProvider = FutureProvider.family<List<Spot>, String>((ref, ownerId) {
  return ref.watch(spotRepositoryProvider).listOwned(ownerId: ownerId);
});

final spotByIdProvider = FutureProvider.family<Spot?, String>((ref, spotId) {
  return ref.watch(spotRepositoryProvider).getSpot(spotId);
});

final spotPhotosProvider = FutureProvider.family<List<SpotPhoto>, String>((ref, spotId) {
  return ref.watch(spotPhotoRepositoryProvider).listSpotPhotos(spotId);
});
