import '../models/booking.dart';

abstract class BookingRepository {
  Future<Booking> createBooking({
    required String spotId,
    required DateTime startTs,
    required DateTime endTs,
  });

  Future<List<Booking>> getMyBookings(String guestId);
  Future<List<Booking>> getBookingsForSpot(String spotId);
  Future<Booking> cancelBooking({required String id, bool hostOverride = false});
}
