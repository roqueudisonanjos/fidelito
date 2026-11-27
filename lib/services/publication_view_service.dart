import 'package:supabase_flutter/supabase_flutter.dart';

/// Registra aberturas de ofertas e destaques e consulta os totais da empresa.
class PublicationViewService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<void> recordView({required String type, required String id}) async {
    if (type != 'offer' && type != 'story') return;
    try {
      await _db.rpc('record_publication_view', params: {
        'p_publication_type': type,
        'p_publication_id': id,
      });
    } catch (_) {
      // A falha na métrica nunca deve impedir o cliente de abrir a publicação.
    }
  }

  Future<Set<String>> getViewedStoryIds() async {
    try {
      final rows = await _db.rpc('get_customer_viewed_stories');
      return Set<String>.from((rows as List).map((id) => id.toString()));
    } catch (_) {
      return <String>{};
    }
  }

  Future<Map<String, int>> getCompanyCounts(String companyId) async {
    final rows = await _db.rpc('get_company_publication_view_counts', params: {
      'p_company_id': companyId,
    });
    final result = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      result['${row['publication_type']}:${row['publication_id']}'] =
          (row['views'] as num?)?.toInt() ?? 0;
    }
    return result;
  }
}
