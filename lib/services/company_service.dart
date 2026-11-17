import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // BUSCAR EMPRESA DO USUÁRIO
  // ============================================================

  Future<Map<String, dynamic>?> getMyCompany() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final company = await _supabase
        .from('companies')
        .select(
          'id, owner_id, name, description, phone, address, city, state, logo_url, active, suspended_at',
        )
        .eq('owner_id', user.id)
        .maybeSingle();

    return company;
  }

  // ============================================================
  // ATUALIZAR EMPRESA
  // ============================================================

  Future<void> updateCompany({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? logoUrl,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await _supabase.rpc(
      'update_my_company',
      params: {
        'p_name': name.trim(),
        'p_description': description,
        'p_phone': phone,
        'p_address': address,
        'p_city': city,
        'p_state': state?.trim().toUpperCase(),
        'p_logo_url': logoUrl,
      },
    );
  }

  Future<Map<String, dynamic>> createCompany({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? city,
    String? state,
  }) async {
    final result = await _supabase.rpc(
      'create_company',
      params: {
        'p_name': name,
        'p_description': description,
        'p_phone': phone,
        'p_address': address,
        'p_city': city,
        'p_state': state,
      },
    );

    return Map<String, dynamic>.from(result);
  }
}
