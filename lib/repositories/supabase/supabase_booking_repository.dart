import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking.dart';
import '../booking_repository.dart';
import 'rpc_invoker.dart';

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository({
    SupabaseClient? client,
    RpcInvoker? rpc,
  })  : _client = client ?? Supabase.instance.client,
        _rpc = rpc ??
            ((fn, {params}) => (client ?? Supabase.instance.client)
                .rpc(fn, params: params));

  final SupabaseClient _client;
  final RpcInvoker _rpc;

  static const _table = 'bookings';
  static const _createBookingRpc = 'create_booking';

  @override
  Future<Booking> createBooking({
    required String spotId,
    required DateTime startTs,
    required DateTime endTs,
  }) async {
    final result = await _rpc(
      _createBookingRpc,
      params: <String, dynamic>{
        'p_spot': spotId,
        'p_start': startTs.toIso8601String(),
        'p_end': endTs.toIso8601String(),
      },
    );

    if (result == null) {
      throw StateError('Booking RPC returned null');
    }

    final Map<String, dynamic> json;
    if (result is Map) {
      json = Map<String, dynamic>.from(result as Map);
    } else if (result is List && result.isNotEmpty) {
      json = Map<String, dynamic>.from(result.first as Map);
    } else {
      throw StateError('Unexpected booking RPC payload: $result');
    }

    return Booking.fromJson(json);
  }

  @override
  Future<List<Booking>> getMyBookings(String guestId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('guest_id', guestId)
        .order('start_ts', ascending: true);

    return (response as List<dynamic>)
        .map((row) => Booking.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> cancelBooking(String id) {
    return _client.from(_table).delete().eq('id', id);
  }
}
