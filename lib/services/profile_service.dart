import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    String? avatarUrl,
    List<String> customerInterests = const [],
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await _supabase.rpc(
      'update_my_profile_with_interests',
      params: {
        'p_full_name': fullName.trim(),
        'p_whatsapp': whatsapp.replaceAll(RegExp(r'\D'), ''),
        'p_city': city.trim().isEmpty ? null : city.trim(),
        'p_state': state.trim().isEmpty ? null : state.trim().toUpperCase(),
        'p_avatar_url': avatarUrl,
        'p_customer_interests': customerInterests,
      },
    );
  }
}
