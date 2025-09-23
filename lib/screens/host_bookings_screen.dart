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
                  return _HostSpotBookingsTile(
                    group: group,
                    ownerId: user.id,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _HostSpotBookingsTile extends ConsumerStatefulWidget {
  const _HostSpotBookingsTile({
    required this.group,
    required this.ownerId,
  });

  final SpotBookings group;
  final String ownerId;

  @override
  ConsumerState<_HostSpotBookingsTile> createState() => _HostSpotBookingsTileState();
}

class _HostSpotBookingsTileState extends ConsumerState<_HostSpotBookingsTile> {
  String? _cancellingId;

  Future<void> _cancelBooking(String bookingId) async {
    setState(() => _cancellingId = bookingId);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancelBooking(id: bookingId, hostOverride: true);
      ref.invalidate(hostSpotBookingsProvider(widget.ownerId));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Booking cancelled')),
          );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $error')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _cancellingId = null);
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'cancelled_guest':
        return 'Cancelled by guest';
      case 'cancelled_host':
        return 'Cancelled by host';
      default:
        return 'Confirmed';
    }
  }

  Color? _statusColor(String status, ColorScheme scheme) {
    if (status == 'cancelled_guest' || status == 'cancelled_host') {
      return scheme.errorContainer;
    }
    return scheme.secondaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.bookings.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(widget.group.spot.title),
          subtitle: const Text('No bookings yet.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: ExpansionTile(
        title: Text(widget.group.spot.title),
        subtitle: Text('${widget.group.bookings.length} booking(s)'),
        children: [
          for (final booking in widget.group.bookings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatRange(booking.startTs, booking.endTs),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_statusLabel(booking.status)),
                        backgroundColor: _statusColor(booking.status, scheme),
                        labelStyle: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Guest: ${booking.guestId}'),
                  const SizedBox(height: 4),
                  Text('${booking.priceTotal.toStringAsFixed(2)}€'),
                  const SizedBox(height: 4),
                  if (booking.status == 'cancelled_guest')
                    const Text('Guest cancelled this booking.'),
                  if (booking.status == 'cancelled_host')
                    const Text('You cancelled this booking.'),
                  if (booking.status == 'confirmed')
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _cancellingId == booking.id
                            ? null
                            : () => _cancelBooking(booking.id),
                        icon: _cancellingId == booking.id
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_schedule_send),
                        label: Text(
                          _cancellingId == booking.id
                              ? 'Cancelling…'
                              : 'Cancel booking',
                        ),
                      ),
                    ),
                ],
              ),
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
