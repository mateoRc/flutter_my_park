import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/host_spot_form_screen.dart';
import 'screens/host_spots_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/spot_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routeAuthNotifierProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(supabaseClientProvider).auth;
      final session = auth.currentSession;
      final loggingIn = state.uri.path == '/login';
      final isHost = auth.currentUser?.userMetadata?['is_host'] == true;
      final isHostRoute = state.uri.path.startsWith('/host');

      if (session == null) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/home';
      }

      if (isHostRoute && !isHost) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/spots/map',
        name: 'spots-map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/spots/:id',
        name: 'spot-detail',
        builder: (context, state) => SpotDetailScreen(spotId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/host/spots',
        name: 'host-spots',
        builder: (context, state) => const HostSpotsScreen(),
      ),
      GoRoute(
        path: '/host/spots/new',
        name: 'host-spot-create',
        builder: (context, state) => const HostSpotFormScreen(),
      ),
      GoRoute(
        path: '/host/spots/:id',
        name: 'host-spot-edit',
        builder: (context, state) => HostSpotFormScreen(
          spotId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
