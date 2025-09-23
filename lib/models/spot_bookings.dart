import 'booking.dart';
import 'spot.dart';

class SpotBookings {
  const SpotBookings({
    required this.spot,
    required this.bookings,
  });

  final Spot spot;
  final List<Booking> bookings;
}
