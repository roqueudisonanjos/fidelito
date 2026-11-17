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

  Future<Map<String, dynamic>?> getBenefitById(String redemptionId) async {
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
          ),

          profiles (
            full_name,
            avatar_url
          )
        ''')
        .eq('id', redemptionId)
        .maybeSingle();

    return response;
  }
}
