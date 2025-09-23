import 'package:supabase_flutter/supabase_flutter.dart';

class BookingException implements Exception {
  BookingException({required this.code, required this.message, this.original});

  final String code;
  final String message;
  final Object? original;

  @override
  String toString() => message;
}

BookingException mapBookingException(
  PostgrestException error, {
  required bool isCancellation,
}) {
  // Handle potential null values and ensure that we are working with a String
  final rawCode = (error.message ?? error.details ?? error.code ?? 'booking_unknown')
      .toString()
      .trim(); // Ensure it's treated as a String and trim it

  // Normalize the raw code in case it's empty
  final normalizedCode = rawCode.isEmpty ? 'booking_unknown' : rawCode;

  // Fetch the friendly message based on the normalized error code
  final friendly = _friendlyMessages[normalizedCode] ??
      (isCancellation
          ? 'Failed to cancel the booking. Please try again.'
          : 'Failed to create the booking. Please try again.');

  // Return the custom exception
  return BookingException(
    code: normalizedCode,
    message: friendly,
    original: error,
  );
}

const Map<String, String> _friendlyMessages = <String, String>{
  'booking_auth_required': 'Sign in to manage bookings.',
  'booking_end_before_start': 'End time must be after the start time.',
  'booking_must_be_in_future': 'Bookings must start in the future.',
  'booking_spot_not_found': 'That spot is no longer available.',
  'booking_overlap_spot': 'This time overlaps another booking for the spot.',
  'booking_overlap_guest': 'You already have a booking during that time.',
  'booking_not_found': 'We could not find that booking.',
  'booking_cannot_cancel': 'This booking can no longer be cancelled.',
  'booking_started': 'This booking has already started.',
  'booking_cancel_window_closed': 'Guests can cancel only up to 24 hours before start.',
  'booking_cancel_not_allowed': 'You do not have permission to cancel this booking.',
};
