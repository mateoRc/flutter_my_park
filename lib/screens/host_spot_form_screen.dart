import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/spot.dart';
import '../models/profile.dart';
import '../models/spot_photo.dart';
import '../providers.dart';

class HostSpotFormScreen extends ConsumerStatefulWidget {
  const HostSpotFormScreen({super.key, this.spotId});

  final String? spotId;

  bool get isEditing => spotId != null;

  @override
  ConsumerState<HostSpotFormScreen> createState() => _HostSpotFormScreenState();
}

class _HostSpotFormScreenState extends ConsumerState<HostSpotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _priceHourController = TextEditingController();
  final _priceDayController = TextEditingController();
  final _amenitiesController = TextEditingController();
  final _accessInstructionsController = TextEditingController();
  final _mapLinkController = TextEditingController();

  bool _initialisedFromSpot = false;
  bool _submitting = false;
  final List<PlatformFile> _newPhotos = [];

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _priceHourController.dispose();
    _priceDayController.dispose();
    _amenitiesController.dispose();
    _accessInstructionsController.dispose();
    _mapLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
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
        final spotId = widget.spotId;

        if (!widget.isEditing) {
          return _HostSpotFormBody(
            title: 'Create spot',
            formKey: _formKey,
            titleController: _titleController,
            addressController: _addressController,
            latController: _latController,
            lngController: _lngController,
            priceHourController: _priceHourController,
            priceDayController: _priceDayController,
            amenitiesController: _amenitiesController,
            accessInstructionsController: _accessInstructionsController,
            mapLinkController: _mapLinkController,
            newPhotos: _newPhotos,
            onPickPhotos: _pickPhotos,
            onRemoveNewPhoto: _removeNewPhoto,
            onSubmit: () => _submitForm(ownerId: ownerId, existingSpot: null, existingPhotos: const []),
            submitting: _submitting,
            existingPhotos: const [],
            onDeleteExistingPhoto: null,
          );
        }

        final spotAsync = ref.watch(spotByIdProvider(spotId!));
        final photosAsync = ref.watch(spotPhotosProvider(spotId));

        return spotAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            body: Center(child: Text('Failed to load spot: $error')),
          ),
          data: (spot) {
            if (spot == null) {
              return const Scaffold(
                body: Center(child: Text('Spot not found.')),
              );
            }

            if (!_initialisedFromSpot) {
              _titleController.text = spot.title;
              _addressController.text = spot.address ?? '';
              _latController.text = spot.lat.toString();
              _lngController.text = spot.lng.toString();
              _priceHourController.text = spot.priceHour?.toString() ?? '';
              _priceDayController.text = spot.priceDay?.toString() ?? '';
              _amenitiesController.text = spot.amenities.join(', ');
              _accessInstructionsController.text = spot.accessInstructions ?? '';
              _mapLinkController.text = spot.mapLink ?? '';
              _initialisedFromSpot = true;
            }

            return photosAsync.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Scaffold(
                body: Center(child: Text('Failed to load photos: $error')),
              ),
              data: (photos) => _HostSpotFormBody(
                title: 'Edit spot',
                formKey: _formKey,
                titleController: _titleController,
                addressController: _addressController,
                latController: _latController,
                lngController: _lngController,
                priceHourController: _priceHourController,
                priceDayController: _priceDayController,
                amenitiesController: _amenitiesController,
                accessInstructionsController: _accessInstructionsController,
                mapLinkController: _mapLinkController,
                newPhotos: _newPhotos,
                onPickPhotos: _pickPhotos,
                onRemoveNewPhoto: _removeNewPhoto,
                onSubmit: () => _submitForm(
                  ownerId: ownerId,
                  existingSpot: spot,
                  existingPhotos: photos,
                ),
                submitting: _submitting,
                existingPhotos: photos,
                onDeleteExistingPhoto: (photo) async {
                  await ref
                      .read(spotPhotoRepositoryProvider)
                      .deleteSpotPhoto(photo.spotId, photo.path);
                  ref.invalidate(spotPhotosProvider(spot.id));
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _newPhotos.addAll(result.files.where((file) => file.bytes != null));
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  Future<void> _submitForm({
    required String ownerId,
    required Spot? existingSpot,
    required List<SpotPhoto> existingPhotos,
  }) async {
    if (_submitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      _showMessage('Latitude and longitude must be valid numbers.');
      return;
    }

    final priceHour = double.tryParse(_priceHourController.text);
    final priceDay = double.tryParse(_priceDayController.text);
    final amenities = _amenitiesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final spotId = existingSpot?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final spot = Spot(
      id: spotId,
      ownerId: ownerId,
      title: _titleController.text.trim(),
      lat: lat,
      lng: lng,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      priceHour: priceHour,
      priceDay: priceDay,
      amenities: amenities,
      accessInstructions: _accessInstructionsController.text.trim().isEmpty
          ? null
          : _accessInstructionsController.text.trim(),
      mapLink: _mapLinkController.text.trim().isEmpty
          ? null
          : _mapLinkController.text.trim(),
      createdAt: existingSpot?.createdAt ?? now,
    );

    setState(() => _submitting = true);

    try {
      final spotRepository = ref.read(spotRepositoryProvider);
      final profileRepository = ref.read(profileRepositoryProvider);
      final profile = await profileRepository.getProfile(ownerId);
      if (profile == null) {
        final authUser = ref.read(supabaseClientProvider).auth.currentUser;
        await profileRepository.updateProfile(
          Profile(
            id: ownerId,
            name: authUser?.userMetadata?['full_name'] as String? ?? authUser?.email,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }

      final photoRepository = ref.read(spotPhotoRepositoryProvider);

      if (existingSpot == null) {
        await spotRepository.createSpot(spot);
      } else {
        await spotRepository.updateSpot(spot);
      }

      final baseOrder = existingPhotos.length;
      for (var i = 0; i < _newPhotos.length; i++) {
        final file = _newPhotos[i];
        final bytes = file.bytes;
        if (bytes == null) {
          continue;
        }
        final extension = (file.extension ?? 'jpg').toLowerCase();
        final filename = '${const Uuid().v4()}.$extension';
        final storagePath = '$spotId/$filename';
        final contentType = _guessContentType(extension);

        await photoRepository.uploadSpotPhoto(
          spotId: spotId,
          path: storagePath,
          bytes: bytes,
          order: baseOrder + i,
          contentType: contentType,
        );
      }

      ref.invalidate(hostSpotsProvider(ownerId));
      if (existingSpot != null) {
        ref.invalidate(spotPhotosProvider(spotId));
      }

      if (!mounted) return;
      _newPhotos.clear();
      _showMessage(existingSpot == null ? 'Spot created.' : 'Spot updated.');
      context.go('/host/spots');
    } catch (error) {
      _showMessage('Failed to save spot: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _guessContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HostSpotFormBody extends StatelessWidget {
  const _HostSpotFormBody({
    required this.title,
    required this.formKey,
    required this.titleController,
    required this.addressController,
    required this.latController,
    required this.lngController,
    required this.priceHourController,
    required this.priceDayController,
    required this.amenitiesController,
    required this.accessInstructionsController,
    required this.mapLinkController,
    required this.newPhotos,
    required this.onPickPhotos,
    required this.onRemoveNewPhoto,
    required this.onSubmit,
    required this.submitting,
    required this.existingPhotos,
    required this.onDeleteExistingPhoto,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController addressController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController priceHourController;
  final TextEditingController priceDayController;
  final TextEditingController amenitiesController;
  final TextEditingController accessInstructionsController;
  final TextEditingController mapLinkController;
  final List<PlatformFile> newPhotos;
  final Future<void> Function() onPickPhotos;
  final void Function(int index) onRemoveNewPhoto;
  final Future<void> Function() onSubmit;
  final bool submitting;
  final List<SpotPhoto> existingPhotos;
  final Future<void> Function(SpotPhoto photo)? onDeleteExistingPhoto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Required'
                        : double.tryParse(value) == null
                            ? 'Invalid number'
                            : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: lngController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Required'
                        : double.tryParse(value) == null
                            ? 'Invalid number'
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: priceHourController,
                    decoration: const InputDecoration(labelText: 'Price per hour (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      return double.tryParse(value) == null ? 'Invalid number' : null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: priceDayController,
                    decoration: const InputDecoration(labelText: 'Price per day (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      return double.tryParse(value) == null ? 'Invalid number' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amenitiesController,
              decoration: const InputDecoration(
                labelText: 'Amenities',
                helperText: 'Comma-separated (e.g. covered, charger, secured)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: accessInstructionsController,
              decoration: const InputDecoration(
                labelText: 'Access instructions',
                helperText: 'Share arrival details, gate codes, or parking tips.',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: mapLinkController,
              decoration: const InputDecoration(
                labelText: 'Custom map link',
                helperText: 'Optional; paste a Google/Apple Maps link for guests.',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final uri = Uri.tryParse(value.trim());
                if (uri == null || uri.scheme.isEmpty) {
                  return 'Enter a valid URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < newPhotos.length; i++)
                  Chip(
                    label: Text(newPhotos[i].name),
                    onDeleted: () => onRemoveNewPhoto(i),
                  ),
                TextButton.icon(
                  onPressed: submitting ? null : onPickPhotos,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Add photos'),
                ),
              ],
            ),
            if (existingPhotos.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Existing photos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final photo in existingPhotos)
                Card(
                  child: ListTile(
                    title: Text(photo.path.split('/').last),
                    subtitle: Text(photo.path),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: submitting || onDeleteExistingPhoto == null
                          ? null
                          : () => onDeleteExistingPhoto!(photo),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(submitting ? 'Saving...' : 'Save spot'),
            ),
          ],
        ),
      ),
    );
  }
}

