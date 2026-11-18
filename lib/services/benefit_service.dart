import 'package:supabase_flutter/supabase_flutter.dart';

class BenefitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyBenefits() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final response = await _supabase
        .from('promotion_redemptions')
        .select('''
          id,
          promotion_id,
          company_id,
          customer_id,
          points_spent,
          status,
          redeemed_at,
          used_at,
          created_at,

          promotions (
            id,
            title,
            description,
            type,
            discount_percentage,
            gift_description,
            image_url,
            ends_at
          ),

          companies (
            id,
            name,
            logo_url
          )
        ''')
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> validateBenefit(String redemptionId) async {
    final response = await _supabase.rpc(
      'validate_promotion_redemption',
      params: {'p_redemption_id': redemptionId},
    );

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> useBenefit(String redemptionId) async {
    try {
      final response = await _supabase.rpc(
        'use_promotion_redemption',
        params: {'p_redemption_id': redemptionId},
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Lista recompensas disponíveis de um cliente pertencente à empresa autenticada.
  Future<List<Map<String, dynamic>>> getAvailableBenefitsForCustomer(
    String customerId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final company = await _supabase
        .from('companies')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (company == null) {
      throw Exception('Empresa não encontrada.');
    }

    final response = await _supabase
        .from('promotion_redemptions')
        .select('''
          id,
          promotion_id,
          company_id,
          customer_id,
          points_spent,
          status,
          redeemed_at,
          promotions (
            title,
            description,
            type,
            discount_percentage,
            gift_description,
            image_url,
            ends_at
          )
        ''')
        .eq('company_id', company['id'].toString())
        .eq('customer_id', customerId)
        .eq('status', 'available')
        .order('redeemed_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Histórico de recompensas utilizadas pela empresa autenticada.
  Future<List<Map<String, dynamic>>> getUsedBenefitsForCompany() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final company = await _supabase
        .from('companies')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (company == null) {
      throw Exception('Empresa não encontrada.');
    }

    // Os perfis são consultados separadamente porque não há FK
    // promotion_redemptions.customer_id -> profiles.id.
    final response = await _supabase
        .from('promotion_redemptions')
        .select('''
          id,
          promotion_id,
          customer_id,
          points_spent,
          status,
          redeemed_at,
          used_at,
          promotions (title, description, type)
        ''')
        .eq('company_id', company['id'].toString())
        .eq('status', 'used')
        .order('used_at', ascending: false);

    final redemptions = List<Map<String, dynamic>>.from(response);
    if (redemptions.isEmpty) return redemptions;

    final customerIds = redemptions
        .map((item) => item['customer_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (customerIds.isEmpty) return redemptions;

    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, full_name, whatsapp, avatar_url')
        .inFilter('id', customerIds);

    final profilesById = <String, Map<String, dynamic>>{
      for (final profile in List<Map<String, dynamic>>.from(profilesResponse))
        profile['id'].toString(): profile,
    };

    for (final redemption in redemptions) {
      final customerId = redemption['customer_id']?.toString();
      redemption['profiles'] =
          customerId == null ? null : profilesById[customerId];
    }

    return redemptions;
  }

  /// Consulta uma recompensa pelo código manual.
  /// O perfil é buscado separadamente para não depender de uma FK
  /// inexistente entre promotion_redemptions.customer_id e profiles.id.
  Future<Map<String, dynamic>?> getBenefitById(String redemptionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final company = await _supabase
        .from('companies')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (company == null) {
      throw Exception('Empresa não encontrada.');
    }

    final response = await _supabase
        .from('promotion_redemptions')
        .select('''
          id,
          status,
          points_spent,
          redeemed_at,
          used_at,
          promotion_id,
          company_id,
          customer_id,
          promotions (
            title,
            description,
            type,
            discount_percentage,
            gift_description,
            image_url,
            ends_at
          )
        ''')
        .eq('id', redemptionId)
        .eq('company_id', company['id'].toString())
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final benefit = Map<String, dynamic>.from(response);
    final customerId = benefit['customer_id']?.toString();

    if (customerId != null && customerId.isNotEmpty) {
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', customerId)
          .maybeSingle();

      benefit['profiles'] = profileResponse == null
          ? null
          : Map<String, dynamic>.from(profileResponse);
    } else {
      benefit['profiles'] = null;
    }

    return benefit;
  }
}
