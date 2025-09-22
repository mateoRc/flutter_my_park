import '../models/booking.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String spotId,
    required DateTime startTs,
    required DateTime endTs,
  });

  Future<List<Booking>> getMyBookings(String guestId);
  Future<void> cancelBooking(String id);
}
