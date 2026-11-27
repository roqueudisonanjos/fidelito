import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyStoryService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Busca destaques públicos e ativos.
  ///
  /// - [companyId]: retorna somente os destaques desta empresa (filtro no banco).
  /// - [city] e [state]: retornam os destaques das empresas dessa cidade/UF.
  ///
  /// Os parâmetros são opcionais e podem ser combinados.
  Future<List<Map<String, dynamic>>> getPublicStories({
    String? city,
    String? state,
    String? companyId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final filter = _db
        .from('company_stories')
        .select('*, companies!inner(id,name,logo_url,city,state,active)')
        .eq('active', true)
        .eq('companies.active', true)
        .gt('expires_at', nowIso);

    final rows = await (companyId != null && companyId.isNotEmpty
            ? filter.eq('company_id', companyId)
            : filter)
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(rows);

    final cityFilter = (city ?? '').trim();
    final stateFilter = (state ?? '').trim();
    if (cityFilter.isEmpty || stateFilter.isEmpty) {
      return list;
    }

    String norm(String? value) {
      var result = (value ?? '').trim().toLowerCase();
      const accents = {
        'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
        'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
        'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
      };
      accents.forEach((from, to) => result = result.replaceAll(from, to));
      return result.replaceAll(RegExp(r'\s+'), ' ');
    }

    const stateAliases = {
      'para': 'pa', 'pa': 'pa',
      'sao paulo': 'sp', 'sp': 'sp',
      'rio de janeiro': 'rj', 'rj': 'rj',
      'minas gerais': 'mg', 'mg': 'mg',
    };

    final normalizedState = stateAliases[norm(stateFilter)] ?? norm(stateFilter);
    final normalizedCity = norm(cityFilter);

    return list.where((row) {
      final company = Map<String, dynamic>.from(row['companies'] ?? {});
      final companyState = norm(company['state']?.toString());
      return norm(company['city']?.toString()) == normalizedCity &&
          (stateAliases[companyState] ?? companyState) == normalizedState;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMyStories(String companyId) async {
    final rows = await _db
        .from('company_stories')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createStory({
    String? id,
    required String companyId,
    required List<String> mediaUrls,
    required String description,
    required DateTime expiresAt,
  }) async {
    final payload = {
      'media_url': mediaUrls.first,
      'media_urls': mediaUrls,
      'description': description.trim().isEmpty ? null : description.trim(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
    };
    if (id == null) {
      await _db.from('company_stories').insert({
        ...payload,
        'company_id': companyId,
        'active': true,
      });
    } else {
      await _db
          .from('company_stories')
          .update(payload)
          .eq('id', id)
          .eq('company_id', companyId);
    }
  }

  Future<void> setActive(String id, String companyId, bool active) async {
    await _db
        .from('company_stories')
        .update({'active': active})
        .eq('id', id)
        .eq('company_id', companyId);
  }
}