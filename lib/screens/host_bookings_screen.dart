import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot_bookings.dart';
import '../providers.dart';

class HostBookingsScreen extends ConsumerWidget {
  const HostBookingsScreen({super.key});

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
        final isHost = user?.userMetadata?['is_host'] == true;
        if (user == null || !isHost) {
          return const Scaffold(
            body: Center(child: Text('Host access is required to view bookings.')),
          );
        }

        final groupsAsync = ref.watch(hostSpotBookingsProvider(user.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Spot bookings'),
          ),
          body: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('Failed to load bookings: $error'),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return const Center(
                  child: Text('No spots yet. Create a listing to start receiving bookings.'),
                );
              }

              final hasAnyBookings = groups.any((group) => group.bookings.isNotEmpty);
              if (!hasAnyBookings) {
                return const Center(
                  child: Text('Your spots have no bookings yet. Share them with guests!'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _HostSpotBookingsTile(group: group);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _HostSpotBookingsTile extends StatelessWidget {
  const _HostSpotBookingsTile({required this.group});

  final SpotBookings group;

  @override
  Widget build(BuildContext context) {
    if (group.bookings.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(group.spot.title),
          subtitle: const Text('No bookings yet.'),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(group.spot.title),
        subtitle: Text('${group.bookings.length} booking(s)'),
        children: [
          for (final booking in group.bookings)
            ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(_formatRange(booking.startTs, booking.endTs)),
              subtitle: Text('Guest: ${booking.guestId}'),
              trailing: Text('EUR ${booking.priceTotal.toStringAsFixed(2)}'),
            ),
        ],
      ),
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
