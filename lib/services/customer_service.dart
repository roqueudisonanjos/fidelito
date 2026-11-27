import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loyalty_transaction.dart';
import '../models/promotion.dart';

class CustomerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    return user.id;
  }

  Future<List<LoyaltyTransaction>> getAllTransactions() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final response = await _supabase
        .from('loyalty_transactions')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    return response
        .map<LoyaltyTransaction>(
          (item) => LoyaltyTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getProfile() async {
    return await _supabase
        .from('profiles')
        .select('id, full_name, phone, role, avatar_url, city, state')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<Map<String, int>> getPointsByCompany() async {
    final response = await _supabase
        .from('loyalty_accounts')
        .select('company_id, points')
        .eq('customer_id', userId)
        .isFilter('left_at', null);
    final result = <String, int>{};
    for (final row in response) {
      result[row['company_id'].toString()] =
          (row['points'] as num?)?.toInt() ?? 0;
    }
    return result;
  }

  Future<int> getPoints() async {
    final response = await _supabase
        .from('loyalty_accounts')
        .select('points')
        .eq('customer_id', userId)
        .isFilter('left_at', null);

    if (response.isEmpty) {
      return 0;
    }

    int total = 0;

    for (final account in response) {
      total += (account['points'] as num?)?.toInt() ?? 0;
    }

    return total;
  }

  Future<List<Promotion>> getPromotions() async {
    final accounts = await _supabase
        .from('loyalty_accounts')
        .select('company_id, left_at, companies(active)')
        .eq('customer_id', userId)
        .isFilter('left_at', null);
    final companyIds = accounts
        .where(
          (row) =>
              row['companies'] != null &&
              (row['companies'] as Map)['active'] == true,
        )
        .map((row) => row['company_id'].toString())
        .toList();
    if (companyIds.isEmpty) return [];

    final response = await _supabase
        .from('promotions')
        .select(
          'id, company_id, title, description, type, points_required, '
          'discount_percentage, gift_description, image_url, media_urls, starts_at, ends_at, companies(name, logo_url)',
        )
        .inFilter('company_id', companyIds)
        .eq('active', true)
        .isFilter('deleted_at', null)
        .order('points_required');

    final now = DateTime.now().toUtc();
    final active = response.where((item) {
      final pointsRequired = (item['points_required'] as num?)?.toInt() ?? 0;
      if (pointsRequired <= 0) return false;
      final starts = item['starts_at'] == null
          ? null
          : DateTime.tryParse(item['starts_at'].toString())?.toUtc();
      final ends = item['ends_at'] == null
          ? null
          : DateTime.tryParse(item['ends_at'].toString())?.toUtc();
      return (starts == null || !now.isBefore(starts)) &&
          (ends == null || !now.isAfter(ends));
    });

    return active.map<Promotion>((item) {
      final map = Map<String, dynamic>.from(item);
      final company = map['companies'];
      if (company is Map) {
        map['company_name'] = company['name'];
        map['company_logo_url'] = company['logo_url'];
      }
      return Promotion.fromMap(map);
    }).toList();
  }

  Future<List<LoyaltyTransaction>> getTransactions() async {
    final response = await _supabase
        .from('loyalty_transactions')
        .select()
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return response
        .map<LoyaltyTransaction>(
          (item) => LoyaltyTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
