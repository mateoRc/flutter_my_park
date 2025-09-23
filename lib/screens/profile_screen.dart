import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../providers.dart';
import '../utils/phone_formatter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            body: Center(child: Text('Sign in to manage your profile.')),
          );
        }

        final profileAsync = ref.watch(profileProvider(user.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My profile'),
          ),
          body: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('Failed to load profile: $error'),
            ),
            data: (profile) {
              _initialiseControllersIfNeeded(user, profile);

              final isHost = user.userMetadata?['is_host'] == true;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email ?? 'Unknown email',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(isHost ? 'Host' : 'Guest'),
                        avatar: Icon(
                          isHost ? Icons.workspace_premium : Icons.person,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          helperText: 'Shared with hosts/guests on bookings.',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          helperText: 'Use international format, e.g. +385123456.',
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                        ],
                        validator: (value) => validatePhoneNumber(value ?? ''),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _saveProfile(user, profile),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving…' : 'Save profile'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _initialiseControllersIfNeeded(User user, Profile? profile) {
    if (_initialised) {
      return;
    }

    final profileName = profile?.name;
    final initialName = (profileName != null && profileName.trim().isNotEmpty)
        ? profileName
        : (user.userMetadata?['full_name'] as String?) ?? (user.email ?? '');
    final initialPhone = profile?.phone ?? '';

    _nameController.text = initialName;
    _phoneController.text = formatPhoneNumberForDisplay(initialPhone);
    _initialised = true;
  }

  Future<void> _saveProfile(User user, Profile? current) async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(profileRepositoryProvider);
      final normalizedPhone = normalizePhoneNumber(_phoneController.text);
      final updated = Profile(
        id: user.id,
        name: _nameController.text.trim(),
        phone: normalizedPhone.isEmpty ? null : normalizedPhone,
        createdAt: current?.createdAt ?? DateTime.now().toUtc(),
      );

      await repository.updateProfile(updated);

      if (user.userMetadata?['needs_profile'] == true) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'needs_profile': false}),
          );
        } catch (_) {
          // Non-fatal: metadata update failure should not block profile saves.
        }
      }

      ref.invalidate(profileProvider(user.id));
      if (mounted) {
        setState(() {
          _initialised = false;
        });
        _phoneController.text = formatPhoneNumberForDisplay(normalizedPhone);
      } else {
        return;
      }

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Failed to save profile: $error')),
        );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
