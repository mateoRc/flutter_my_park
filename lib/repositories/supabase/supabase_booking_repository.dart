import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking.dart';
import '../booking_repository.dart';

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'bookings';

  @override
  Future<Booking> createBooking({
    required String spotId,
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final payload = <String, dynamic>{
      'spot_id': spotId,
      'user_id': userId,
      'start_at': start.toIso8601String(),
      'end_at': end.toIso8601String(),
    };

    final inserted = await _client
        .from(_table)
        .insert(payload)
        .select()
        .single();
    return Booking.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<List<Booking>> getMyBookings(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('start_at', ascending: true);

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
