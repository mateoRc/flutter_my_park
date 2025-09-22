import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_my_park/models/booking.dart';
import 'package:flutter_my_park/repositories/supabase/supabase_booking_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRpc extends Mock {
  Future<dynamic> call(String function, {Map<String, dynamic>? params});
}

void main() {
  late _MockSupabaseClient client;
  late _MockRpc rpc;
  late SupabaseBookingRepository repository;

  setUp(() {
    client = _MockSupabaseClient();
    rpc = _MockRpc();
    repository = SupabaseBookingRepository(client: client, rpc: rpc.call);
  });

  group('SupabaseBookingRepository.createBooking', () {
    test('invokes RPC and maps result', () async {
      final bookingJson = {
        'id': 'booking-1',
        'spot_id': 'spot-1',
        'guest_id': 'guest-1',
        'start_ts': '2025-05-01T12:00:00Z',
        'end_ts': '2025-05-01T14:00:00Z',
        'price_total': 20.0,
        'status': 'confirmed',
      };

      when(() => rpc.call(
            any<String>(),
            params: any(named: 'params'),
          )).thenAnswer((_) async => bookingJson);

      final booking = await repository.createBooking(
        spotId: 'spot-1',
        startTs: DateTime.parse('2025-05-01T12:00:00Z'),
        endTs: DateTime.parse('2025-05-01T14:00:00Z'),
      );

      expect(booking, isA<Booking>());
      expect(booking.id, 'booking-1');

      final captured = verify(() => rpc.call(
            'create_booking',
            params: captureAny(named: 'params'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['p_spot'], 'spot-1');
      expect(captured['p_start'], '2025-05-01T12:00:00.000Z');
      expect(captured['p_end'], '2025-05-01T14:00:00.000Z');
    });

    test('throws when RPC returns null', () async {
      when(() => rpc.call(
            any<String>(),
            params: any(named: 'params'),
          )).thenAnswer((_) async => null);

      expect(
        () => repository.createBooking(
          spotId: 'spot-1',
          startTs: DateTime.now(),
          endTs: DateTime.now().add(const Duration(hours: 2)),
        ),
        throwsStateError,
      );
    });
  });
}
