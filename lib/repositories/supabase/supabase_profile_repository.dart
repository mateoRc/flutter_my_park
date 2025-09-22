import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) {
      return null;
    }
    return Profile.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Profile> updateProfile(Profile profile) async {
    final data = await _client
        .from('profiles')
        .upsert(profile.toJson())
        .select()
        .maybeSingle();
    return Profile.fromJson(Map<String, dynamic>.from(data ?? profile.toJson()));
  }
}
