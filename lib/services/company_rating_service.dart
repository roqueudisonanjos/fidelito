import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyRatingService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<Map<String, Map<String, dynamic>>> getStats(List<String> companyIds) async {
    if (companyIds.isEmpty) return {};
    final rows = await _db.rpc('get_company_rating_stats', params: {
      'p_company_ids': companyIds,
    });
    final result = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      result[row['company_id'].toString()] = Map<String, dynamic>.from(row);
    }
    return result;
  }

  Future<int?> getMyRating(String companyId) async {
    final stats = await getStats([companyId]);
    return (stats[companyId]?['my_rating'] as num?)?.toInt();
  }

  Future<void> submit(String companyId, int stars) async {
    await _db.rpc('submit_company_rating', params: {
      'p_company_id': companyId,
      'p_stars': stars,
    });
  }
}
