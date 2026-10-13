import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promotion_redemption.dart';

class RedemptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PromotionRedemption>> getMyRedemptions() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuário não autenticado.',
      );
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
            title,
            description,
            type,
            discount_percentage,
            gift_description
          ),

          companies (
            name
          )
        ''')
        .eq(
          'customer_id',
          user.id,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List).map((item) =>PromotionRedemption.fromMap(
        Map<String, dynamic>.from(item),
      ),
    ).toList();

  }
}
