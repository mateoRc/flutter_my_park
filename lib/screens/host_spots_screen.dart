import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/spot.dart';
import '../providers.dart';

class HostSpotsScreen extends ConsumerWidget {
  const HostSpotsScreen({super.key});

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
        if (!isHost) {
          return const Scaffold(
            body: Center(child: Text('Host access is required to manage spots.')),
          );
        }

        final ownerId = user!.id;
        final spotsAsync = ref.watch(hostSpotsProvider(ownerId));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Spots'),
            actions: [
              IconButton(
                icon: const Icon(Icons.event_note),
                tooltip: 'View bookings',
                onPressed: () => context.go('/host/bookings'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/host/spots/new'),
            icon: const Icon(Icons.add),
            label: const Text('New spot'),
          ),
          body: spotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('Failed to load spots: $error'),
            ),
            data: (spots) {
              if (spots.isEmpty) {
                return const Center(
                  child: Text('No spots yet. Create your first one!'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                itemCount: spots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final spot = spots[index];
                  return _SpotCard(spot: spot);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(spot.title),
        subtitle: Text(spot.address ?? 'No address'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Edit',
          onPressed: () => context.go('/host/spots/${spot.id}'),
        ),
      ),
    );
  }
}
