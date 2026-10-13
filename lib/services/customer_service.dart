import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loyalty_transaction.dart';
import '../models/promotion.dart';

class CustomerService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  String get userId {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuário não autenticado.',
      );
    }

    return user.id;
  }

  Future<List<LoyaltyTransaction>>
      getAllTransactions() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuário não autenticado.',
      );
    }

    final response =
        await _supabase
            .from('loyalty_transactions')
            .select()
            .eq(
              'customer_id',
              user.id,
            )
            .order(
              'created_at',
              ascending: false,
            );

    return response
        .map<LoyaltyTransaction>(
          (item) =>
              LoyaltyTransaction.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>?>
      getProfile() async {
    return await _supabase
        .from('profiles')
        .select(
          'id, full_name, phone, role',
        )
        .eq(
          'id',
          userId,
        )
        .maybeSingle();
  }

  Future<int> getPoints() async {
    final response =
        await _supabase
            .from('loyalty_accounts')
            .select('points')
            .eq(
              'customer_id',
              userId,
            );

    if (response.isEmpty) {
      return 0;
    }

    int total = 0;

    for (final account in response) {
      total +=
          (account['points'] as int?) ?? 0;
    }

    return total;
  }

  Future<List<Promotion>>
      getPromotions() async {
    final response =
        await _supabase
            .from('promotions')
            .select(
              'id, '
              'company_id, '
              'title, '
              'description, '
              'type, '
              'points_required, '
              'discount_percentage, '
              'gift_description, '
              'starts_at, '
              'ends_at',
            )
            .eq(
              'active',
              true,
            )
            .order(
              'points_required',
            );

    return response
        .map<Promotion>(
          (item) =>
              Promotion.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  Future<List<LoyaltyTransaction>>
      getTransactions() async {
    final response =
        await _supabase
            .from('loyalty_transactions')
            .select()
            .eq(
              'customer_id',
              userId,
            )
            .order(
              'created_at',
              ascending: false,
            )
            .limit(20);

    return response
        .map<LoyaltyTransaction>(
          (item) =>
              LoyaltyTransaction.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }
}