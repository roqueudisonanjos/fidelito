import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // BUSCAR EMPRESA DO USUÁRIO
  // ============================================================

  Future<Map<String, dynamic>?> getMyCompany() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuário não autenticado.',
      );
    }

    final company = await _supabase
        .from('companies')
        .select(
          'id, owner_id, name, description, phone, address, logo_url, active',
        )
        .eq(
          'owner_id',
          user.id,
        )
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
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuário não autenticado.',
      );
    }

    final company = await _supabase
        .from('companies')
        .select('id')
        .eq(
          'owner_id',
          user.id,
        )
        .maybeSingle();

    if (company == null) {
      throw Exception(
        'Empresa não encontrada.',
      );
    }

    await _supabase
        .from('companies')
        .update({
          'name': name,
          'description': description,
          'phone': phone,
          'address': address,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq(
          'id',
          company['id'],
        );
  }

  Future<Map<String, dynamic>> createCompany({
    required String name,
    String? description,
    String? phone,
    String? address,
  }) async {
    final result = await _supabase.rpc(
      'create_company',
      params: {
        'p_name': name,
        'p_description': description,
        'p_phone': phone,
        'p_address': address,
      },
    );

    return Map<String, dynamic>.from(result);
  }
}