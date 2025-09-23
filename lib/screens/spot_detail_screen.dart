import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers.dart';

class SpotDetailScreen extends ConsumerWidget {
  const SpotDetailScreen({super.key, required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotAsync = ref.watch(spotByIdProvider(spotId));
    final photosAsync = ref.watch(spotPhotosProvider(spotId));
    final sessionAsync = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spot details'),
      ),
      body: spotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Failed to load spot: $error'),
        ),
        data: (spot) {
          if (spot == null) {
            return const Center(child: Text('Spot not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                spot.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (spot.address != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 4),
                    Expanded(child: Text(spot.address!)),
                  ],
                ),
              const SizedBox(height: 8),
              Text('Lat ${spot.lat.toStringAsFixed(4)}, Lng ${spot.lng.toStringAsFixed(4)}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (spot.priceHour != null)
                    Chip(label: Text('EUR ${spot.priceHour!.toStringAsFixed(2)}/h')),
                  if (spot.priceDay != null)
                    Chip(label: Text('EUR ${spot.priceDay!.toStringAsFixed(2)}/day')),
                  ...spot.amenities.map((amenity) => Chip(label: Text(amenity))),
                ],
              ),
              const SizedBox(height: 24),
              Text('Photos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              photosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Failed to load photos: $error'),
                data: (photos) {
                  if (photos.isEmpty) {
                    return const Text('No photos uploaded yet.');
                  }
                  return Column(
                    children: [
                      for (final photo in photos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _publicPhotoUrl(photo.path),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildBookingSection(
                context: context,
                ref: ref,
                spot: spot,
                sessionAsync: sessionAsync,
              ),
            ],
          );
        },
      ),
    );
  }

  String _publicPhotoUrl(String path) {
    final storage = Supabase.instance.client.storage.from('spot-photos');
    return storage.getPublicUrl(path);
  }
}

Widget _buildBookingSection({
  required BuildContext context,
  required WidgetRef ref,
  required Spot spot,
  required AsyncValue<Session?> sessionAsync,
}) {
  return sessionAsync.when(
    loading: () => const _SectionCard(
      title: 'Bookings',
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, stackTrace) => _SectionCard(
      title: 'Bookings',
      child: Text('Session error: $error'),
    ),
    data: (session) {
      if (session == null) {
        return const _SectionCard(
          title: 'Bookings',
          child: Text('Sign in to request a booking.'),
        );
      }

      final user = session.user;
      final isOwner = user.id == spot.ownerId;

      if (isOwner) {
        return _SpotOwnerBookingsCard(spot: spot);
      }

      return _SpotBookingForm(
        spot: spot,
        user: user,
      );
    },
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SpotBookingForm extends ConsumerStatefulWidget {
  const _SpotBookingForm({
    required this.spot,
    required this.user,
  });

  final Spot spot;
  final User user;

  @override
  ConsumerState<_SpotBookingForm> createState() => _SpotBookingFormState();
}

class _SpotBookingFormState extends ConsumerState<_SpotBookingForm> {
  DateTime? _start;
  DateTime? _end;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book this spot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Select start and end times. The booking will be confirmed if the spot is still free.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _DateTimePickerTile(
              label: 'Start',
              value: _start,
              onTap: _submitting ? null : () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _DateTimePickerTile(
              label: 'End',
              value: _end,
              onTap: _submitting ? null : () => _pickDateTime(isStart: false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Submitting...' : 'Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final initial = (isStart ? _start : _end) ?? _start ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial.toLocal(),
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (date == null) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial.toLocal()),
    );
    if (time == null) {
      return;
    }

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _start = selected;
        if (_end != null && !_end!.isAfter(_start!)) {
          _end = _start!.add(const Duration(hours: 1));
        }
      } else {
        _end = selected;
      }
    });
  }

  String? _resolvedInstructions() {
    final raw = widget.spot.accessInstructions?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  String _resolvedMapLink() {
    final provided = widget.spot.mapLink?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final lat = widget.spot.lat.toStringAsFixed(6);
    final lng = widget.spot.lng.toStringAsFixed(6);
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

  Future<void> _submit() async {
    final start = _start;
    final end = _end;

    if (start == null || end == null) {
      setState(() => _error = 'Select both start and end times.');
      return;
    }

    if (!end.isAfter(start)) {
      setState(() => _error = 'End time must be after the start time.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      final profile = await profileRepository.getProfile(widget.user.id);
      if (profile == null) {
        await profileRepository.updateProfile(
          Profile(
            id: widget.user.id,
            name: widget.user.userMetadata?['full_name'] as String? ?? widget.user.email,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }

      final booking = await ref.read(bookingRepositoryProvider).createBooking(
        spotId: widget.spot.id,
        startTs: start.toUtc(),
        endTs: end.toUtc(),
      );

      ref.invalidate(guestBookingsProvider(widget.user.id));
      ref.invalidate(spotBookingsProvider(widget.spot.id));
      ref.invalidate(hostSpotBookingsProvider(widget.spot.ownerId));

      if (!mounted) return;

      final instructions = _resolvedInstructions();
      final mapLink = _resolvedMapLink();

      setState(() {
        _start = null;
        _end = null;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final address = widget.spot.address?.trim();
          return AlertDialog(
            title: const Text('Booking created'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your booking is confirmed from ${_formatRange(booking.startTs, booking.endTs)}.',
                  ),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Address', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(address, style: theme.textTheme.bodyMedium),
                  ],
                  if (instructions != null) ...[
                    const SizedBox(height: 12),
                    Text('Access instructions', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      instructions,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Map & directions', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    mapLink,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              TextButton.icon(
                onPressed: () => _openMapLink(mapLink),
                icon: const Icon(Icons.map),
                label: const Text('Open map'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/bookings');
                },
                child: const Text('View my bookings'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Failed to create booking: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = value == null
        ? 'Select $label time'
        : _formatSingleDateTime(value!);

    return ListTile(
      leading: const Icon(Icons.access_time),
      title: Text(label),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SpotOwnerBookingsCard extends ConsumerWidget {
  const _SpotOwnerBookingsCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(spotBookingsProvider(spot.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming bookings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            bookingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Failed to load bookings: $error'),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return const Text('No bookings yet.');
                }
                return Column(
                  children: [
                    for (final booking in bookings)
                      ListTile(
                        leading: const Icon(Icons.event_available),
                        title: Text(_formatRange(booking.startTs, booking.endTs)),
                        subtitle: Text('Guest: ${booking.guestId}'),
                        trailing: Text('EUR ${booking.priceTotal.toStringAsFixed(2)}'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
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

String _formatSingleDateTime(DateTime value) {
  final date = _formatDate(value.toLocal());
  final time = _formatTime(value.toLocal());
  return '$date $time';
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

