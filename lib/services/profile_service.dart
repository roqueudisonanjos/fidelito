import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<void> updateProfile({
    required String fullName,
    required String whatsapp,
    required String city,
    required String state,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await _supabase
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'whatsapp': whatsapp.replaceAll(
            RegExp(r'\D'),
            '',
          ),
          'city': city.trim().isEmpty ? null : city.trim(),
          'state': state.trim().isEmpty ? null : state.trim().toUpperCase(),
        })
        .eq('id', user.id);
  }
}