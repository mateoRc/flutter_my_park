import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers.dart';

class SpotDetailScreen extends ConsumerWidget {
  const SpotDetailScreen({super.key, required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotAsync = ref.watch(spotByIdProvider(spotId));
    final photosAsync = ref.watch(spotPhotosProvider(spotId));

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
                    Chip(label: Text('€${spot.priceHour!.toStringAsFixed(2)}/h')),
                  if (spot.priceDay != null)
                    Chip(label: Text('€${spot.priceDay!.toStringAsFixed(2)}/day')),
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
                    children: photos
                        .map(
                          (photo) => Padding(
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
                        )
                        .toList(),
                  );
                },
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
