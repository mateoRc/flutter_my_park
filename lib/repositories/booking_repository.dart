import '../models/booking.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String spotId,
    required String userId,
    required DateTime start,
    required DateTime end,
  });

  Future<List<Booking>> getMyBookings(String userId);
  Future<void> cancelBooking(String id);
}
