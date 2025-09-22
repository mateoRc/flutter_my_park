import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_my_park/models/spot.dart';
import 'package:flutter_my_park/repositories/supabase/supabase_spot_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRpc extends Mock {
  Future<dynamic> call(String function, {Map<String, dynamic>? params});
}

void main() {
  late _MockSupabaseClient client;
  late _MockRpc rpc;
  late SupabaseSpotRepository repository;

  setUp(() {
    client = _MockSupabaseClient();
    rpc = _MockRpc();
    repository = SupabaseSpotRepository(client: client, rpc: rpc.call);
  });

  group('SupabaseSpotRepository.getNearby', () {
    test('passes coordinates and radius to RPC and maps results', () async {
      const latitude = 45.0;
      const longitude = 15.9;
      const radius = 750.0;

      final response = [
        {
          'id': 'spot-1',
          'owner_id': 'owner-1',
          'title': 'Central Garage',
          'lat': latitude,
          'lng': longitude,
          'amenities': <String>['covered'],
          'created_at': '2025-01-01T00:00:00Z',
        },
      ];

      when(() => rpc.call(
            any<String>(),
            params: any(named: 'params'),
          )).thenAnswer((_) async => response);

      final spots = await repository.getNearby(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
      );

      expect(spots, hasLength(1));
      expect(spots.first, isA<Spot>());
      expect(spots.first.title, 'Central Garage');

      final captured = verify(() => rpc.call(
            'spots_nearby',
            params: captureAny(named: 'params'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['lat_input'], latitude);
      expect(captured['lng_input'], longitude);
      expect(captured['radius_m'], radius);
    });

    test('returns empty list when RPC yields null', () async {
      when(() => rpc.call(
            any<String>(),
            params: any(named: 'params'),
          )).thenAnswer((_) async => null);

      final spots = await repository.getNearby(
        latitude: 0,
        longitude: 0,
      );

      expect(spots, isEmpty);
    });
  });
}
