import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/spot.dart';
import '../providers.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Session error: $error')),
      ),
      data: (session) {
        final user = session?.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Sign in to view bookings.')),
          );
        }

        final bookingsAsync = ref.watch(guestBookingsProvider(user.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My bookings'),
          ),
          body: bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('Failed to load bookings: $error'),
            ),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const Center(
                  child: Text('No bookings yet. Find a spot and book it!'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  return _BookingTile(booking: booking);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotAsync = ref.watch(spotByIdProvider(booking.spotId));

    return spotAsync.when(
      loading: () => const Card(
        child: ListTile(
          title: Text('Loading spot...'),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: ListTile(
          title: Text('Spot unavailable'),
          subtitle: Text('Failed to load spot: $error'),
        ),
      ),
      data: (spot) {
        final title = spot?.title ?? 'Spot ${booking.spotId}';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(title),
            subtitle: Text(_formatRange(booking.startTs, booking.endTs)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('EUR ${booking.priceTotal.toStringAsFixed(2)}'),
                Text(
                  booking.status,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatRange(DateTime start, DateTime end) {
  final localStart = start.toLocal();
  final localEnd = end.toLocal();

  final startDate = _formatDate(localStart);
  final endDate = _formatDate(localEnd);
  final startTime = _formatTime(localStart);
  final endTime = _formatTime(localEnd);

  if (startDate == endDate) {
    return '$startDate $startTime - $endTime';
  }
  return '$startDate $startTime -> $endDate $endTime';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
