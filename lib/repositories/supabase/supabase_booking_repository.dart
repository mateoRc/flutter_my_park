import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking.dart';
import '../booking_repository.dart';
import '../booking_exceptions.dart';
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
  static const _cancelBookingRpc = 'cancel_booking';

  @override
  Future<Booking> createBooking({
    required String spotId,
    required DateTime startTs,
    required DateTime endTs,
  }) async {
    dynamic result;
    try {
      result = await _rpc(
        _createBookingRpc,
        params: <String, dynamic>{
          'p_spot': spotId,
          'p_start': startTs.toIso8601String(),
          'p_end': endTs.toIso8601String(),
        },
      );
    } on PostgrestException catch (error) {
      throw mapBookingException(error, isCancellation: false);
    }

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

    return _mapRows(response);
  }

  @override
  Future<List<Booking>> getBookingsForSpot(String spotId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('spot_id', spotId)
        .order('start_ts', ascending: true);

    return _mapRows(response);
  }

  @override
  Future<Booking> cancelBooking({
    required String id,
    bool hostOverride = false,
  }) async {
    final result = await _rpc(
      _cancelBookingRpc,
      params: <String, dynamic>{
        'p_booking': id,
        'p_host_override': hostOverride,
      },
    );

    if (result == null) {
      throw StateError('Cancel booking RPC returned null');
    }

    final Map<String, dynamic> json;
    if (result is Map) {
      json = Map<String, dynamic>.from(result as Map);
    } else if (result is List && result.isNotEmpty) {
      json = Map<String, dynamic>.from(result.first as Map);
    } else {
      throw StateError('Unexpected cancel booking payload: $result');
    }

    return Booking.fromJson(json);
  }

  List<Booking> _mapRows(dynamic response) {
    return (response as List<dynamic>)
        .map(
          (row) => Booking.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }
}



