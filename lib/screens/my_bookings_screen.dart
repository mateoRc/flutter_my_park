import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking.dart';
import '../models/spot.dart';
import '../providers.dart';
import '../repositories/booking_exceptions.dart';

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
                  return _BookingTile(
                    booking: booking,
                    guestId: user.id,
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

class _BookingTile extends ConsumerStatefulWidget {
  const _BookingTile({
    required this.booking,
    required this.guestId,
  });

  final Booking booking;
  final String guestId;

  @override
  ConsumerState<_BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends ConsumerState<_BookingTile> {
  bool _cancelling = false;

  bool get _isGuestCancelled => widget.booking.status == 'cancelled_guest';
  bool get _isHostCancelled => widget.booking.status == 'cancelled_host';
  bool get _isCancelled => _isGuestCancelled || _isHostCancelled;
  bool get _isConfirmed => widget.booking.status == 'confirmed';

  bool get _isFinished {
    if (_isCancelled) return false;
    final now = DateTime.now().toUtc();
    return now.isAfter(widget.booking.endTs.toUtc());
  }

  bool get _isCurrent => !_isCancelled && !_isFinished;

  bool get _canCancel {
    if (!_isConfirmed) return false;
    final cutoff = widget.booking.startTs.toUtc().subtract(const Duration(hours: 24));
    return DateTime.now().toUtc().isBefore(cutoff);
  }

  String get _statusLabel {
    if (_isGuestCancelled) return 'Cancelled by you';
    if (_isHostCancelled) return 'Cancelled by host';
    if (_isFinished) return 'Finished';
    return 'Active';
  }

  Color? _statusColor(ColorScheme scheme) {
    if (_isGuestCancelled || _isHostCancelled) {
      return scheme.errorContainer;
    }
    if (_isFinished) {
      return scheme.surfaceVariant;
    }
    return scheme.primaryContainer;
  }

  String? _resolvedInstructions(Spot? spot) {
    final raw = spot?.accessInstructions?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  String? _resolvedMapLink(Spot? spot) {
    final provided = spot?.mapLink?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    if (spot == null) {
      return null;
    }
    final lat = spot.lat.toStringAsFixed(6);
    final lng = spot.lng.toStringAsFixed(6);
    return 'https://www.google.com/maps?q=' + lat + ',' + lng;
  }

  Future<void> _openMapLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Map link is invalid.')),
        );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open map link.')),
        );
    }
  }

  Future<void> _cancelBooking() async {
    setState(() => _cancelling = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancelBooking(id: widget.booking.id);
      ref.invalidate(guestBookingsProvider(widget.guestId));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Booking cancelled')),
          );
      }
    } on BookingException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(error.message)),
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
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(spotByIdProvider(widget.booking.spotId));

    return spotAsync.when(
      loading: () => const Card(
        child: ListTile(
          title: Text('Loading spot...'),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: ListTile(
          title: const Text('Spot unavailable'),
          subtitle: Text('Failed to load spot: $error'),
        ),
      ),
      data: (spot) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final title = spot?.title ?? 'Spot ${widget.booking.spotId}';
        final priceText = 'EUR ${widget.booking.priceTotal.toStringAsFixed(2)}';
        final instructions = _resolvedInstructions(spot);
        final mapLink = _resolvedMapLink(spot);
        final address = spot?.address?.trim();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRange(widget.booking.startTs, widget.booking.endTs),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      label: Text(_statusLabel),
                      backgroundColor: _statusColor(scheme),
                      labelStyle: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priceText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isGuestCancelled) ...[
                  Text(
                    'You cancelled this booking.',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else if (_isHostCancelled) ...[
                  Text(
                    'The host cancelled this booking.',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else ...[
                  if (_canCancel)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _cancelling ? null : _cancelBooking,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_schedule_send),
                        label: Text(_cancelling ? 'Cancelling...' : 'Cancel booking'),
                      ),
                    ),
                  if (_isCurrent && spot != null) ...[
                    const SizedBox(height: 16),
                    if (address != null && address.isNotEmpty) ...[
                      Text('Address', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(address, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                    ],
                    if (instructions != null) ...[
                      Text('Access instructions', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        instructions,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (mapLink != null) ...[
                      Text('Map link', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      SelectableText(
                        mapLink,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _openMapLink(mapLink),
                        icon: const Icon(Icons.map),
                        label: const Text('Open map'),
                      ),
                    ],
                  ] else if (_isFinished) ...[
                    Text(
                      'This booking has finished.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (_isConfirmed) ...[
                    Text(
                      'Contact the host to cancel within 24 hours of the start time.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
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


