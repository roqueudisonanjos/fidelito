import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyProgramService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> discoverCompanies({
    String? city,
    String? state,
    String? search,
  }) async {
    var query = _supabase
        .from('companies')
        .select(
          'id, name, description, phone, address, city, state, logo_url, instagram_username, tiktok_username, active',
        )
        .eq('active', true);

    if (city != null && city.trim().isNotEmpty) {
      query = query.ilike('city', '%${city.trim()}%');
    }
    if (state != null && state.trim().isNotEmpty) {
      query = query.ilike('state', state.trim());
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }

    final companies = await query.order('name');
    final accounts = await _supabase
        .from('loyalty_accounts')
        .select('company_id')
        .eq('customer_id', _userId)
        .isFilter('left_at', null);
    final joinedIds = accounts.map((a) => a['company_id'].toString()).toSet();

    return companies.map((company) {
      final item = Map<String, dynamic>.from(company);
      item['joined'] = joinedIds.contains(item['id'].toString());
      return item;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> discoverPromotions({
    String? city,
    String? state,
    String? search,
  }) async {
    final response = await _supabase
        .from('promotions')
        .select('''
          id, company_id, title, description, type, points_required,
          discount_percentage, gift_description, image_url, starts_at, ends_at,
          companies!inner(id, name, city, state, logo_url, active)
        ''')
        .eq('active', true)
        .isFilter('deleted_at', null)
        .eq('companies.active', true)
        .order('created_at', ascending: false);

    final now = DateTime.now().toUtc();
    final cityFilter = city?.trim().toLowerCase() ?? '';
    final stateFilter = state?.trim().toLowerCase() ?? '';
    final searchFilter = search?.trim().toLowerCase() ?? '';

    return List<Map<String, dynamic>>.from(response)
        .where((item) {
          final company = Map<String, dynamic>.from(item['companies'] ?? {});
          final companyCity = (company['city'] ?? '').toString().toLowerCase();
          final companyState = (company['state'] ?? '')
              .toString()
              .toLowerCase();
          final companyName = (company['name'] ?? '').toString().toLowerCase();
          final title = (item['title'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '')
              .toString()
              .toLowerCase();
          final starts = item['starts_at'] == null
              ? null
              : DateTime.tryParse(item['starts_at'].toString())?.toUtc();
          final ends = item['ends_at'] == null
              ? null
              : DateTime.tryParse(item['ends_at'].toString())?.toUtc();
          final inDate =
              (starts == null || !now.isBefore(starts)) &&
              (ends == null || !now.isAfter(ends));
          final matchesCity =
              cityFilter.isEmpty || companyCity.contains(cityFilter);
          final matchesState =
              stateFilter.isEmpty || companyState == stateFilter;
          final matchesSearch =
              searchFilter.isEmpty ||
              companyName.contains(searchFilter) ||
              title.contains(searchFilter) ||
              description.contains(searchFilter);
          return inDate && matchesCity && matchesState && matchesSearch;
        })
        .map((item) {
          final copy = Map<String, dynamic>.from(item);
          copy['company'] = Map<String, dynamic>.from(item['companies'] ?? {});
          copy.remove('companies');
          return copy;
        })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyPrograms() async {
    final response = await _supabase
        .from('loyalty_accounts')
        .select('''
          id,
          company_id,
          points,
          created_at,
          left_at,
          companies (
            id, name, description, phone, address, city, state, logo_url, active
          )
        ''')
        .eq('customer_id', _userId)
        .isFilter('left_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      response,
    ).where((row) => row['companies'] != null).toList();
  }

  Future<Map<String, dynamic>> getCompanyDetails(String companyId) async {
    final response = await _supabase
        .from('companies')
        .select(
          'id, name, description, phone, address, city, state, logo_url, instagram_username, tiktok_username, active',
        )
        .eq('id', companyId)
        .eq('active', true)
        .maybeSingle();

    if (response == null) {
      throw Exception('As informações desta empresa não estão disponíveis.');
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> joinProgram(String companyId) async {
    await _supabase.rpc(
      'join_loyalty_program',
      params: {'p_company_id': companyId},
    );
  }

  Future<void> leaveProgram(String companyId) async {
    await _supabase.rpc(
      'leave_loyalty_program',
      params: {'p_company_id': companyId},
    );
  }

  Future<List<Map<String, dynamic>>> getCompanyTransactions(
    String companyId,
  ) async {
    final response = await _supabase
        .from('loyalty_transactions')
        .select('id, type, points, description, created_at')
        .eq('customer_id', _userId)
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCompanyPromotions(
    String companyId,
  ) async {
    final response = await _supabase
        .from('promotions')
        .select(
          'id, company_id, title, description, type, points_required, discount_percentage, gift_description, image_url, starts_at, ends_at, active',
        )
        .eq('company_id', companyId)
        .eq('active', true)
        .isFilter('deleted_at', null)
        .order('points_required');

    final now = DateTime.now().toUtc();
    return List<Map<String, dynamic>>.from(response).where((p) {
      final starts = p['starts_at'] == null
          ? null
          : DateTime.tryParse(p['starts_at'].toString())?.toUtc();
      final ends = p['ends_at'] == null
          ? null
          : DateTime.tryParse(p['ends_at'].toString())?.toUtc();
      return (starts == null || !now.isBefore(starts)) &&
          (ends == null || !now.isAfter(ends));
    }).toList();
  }
}
