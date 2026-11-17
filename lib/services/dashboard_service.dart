import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // EMPRESA
  // ============================================================

  Future<String> _getCompanyId() async {
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

    return company['id'].toString();
  }

  Future<int> awardPoints({
    required String customerId,
    required int points,
    String? description,
  }) async {
    final result = await _supabase.rpc(
      'award_customer_points',
      params: {
        'p_customer_id': customerId,
        'p_points': points,
        'p_description': description,
      },
    );
    if (result is Map && result['new_balance'] != null) {
      return (result['new_balance'] as num).toInt();
    }
    throw Exception('Não foi possível adicionar os pontos.');
  }

  // ============================================================
  // CLIENTES DA EMPRESA
  // ============================================================

  Future<List<Map<String, dynamic>>> getCompanyCustomers() async {
    final companyId = await _getCompanyId();

    // ----------------------------------------------------------
    // 1. BUSCAR CONTAS DE FIDELIDADE
    //
    // É daqui que identificamos quem são os clientes da empresa.
    // ----------------------------------------------------------

    final accounts = await _supabase
        .from('loyalty_accounts')
        .select('id, customer_id, points, left_at')
        .eq('company_id', companyId)
        .isFilter('left_at', null);

    if (accounts.isEmpty) {
      return [];
    }

    // Mapa:
    // customer_id -> saldo atual
    final pointsByCustomer = <String, int>{};

    for (final account in accounts) {
      final customerId = account['customer_id']?.toString();

      if (customerId == null || customerId.isEmpty) {
        continue;
      }

      pointsByCustomer[customerId] = _toInt(account['points']);
    }

    final customerIds = pointsByCustomer.keys.toList();

    if (customerIds.isEmpty) {
      return [];
    }

    // ----------------------------------------------------------
    // 2. BUSCAR PERFIS
    // ----------------------------------------------------------

    final profilesResponse = await _supabase
        .from('profiles')
        .select('id, full_name, whatsapp, avatar_url')
        .inFilter('id', customerIds);

    final profiles = List<Map<String, dynamic>>.from(profilesResponse);

    // ----------------------------------------------------------
    // 3. BUSCAR TRANSAÇÕES
    //
    // Usaremos somente type = earn para saber quantos pontos
    // o cliente já recebeu ao longo do tempo.
    // ----------------------------------------------------------

    final transactionsResponse = await _supabase
        .from('loyalty_transactions')
        .select('customer_id, promotion_id, points, type, created_at')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);

    final transactions = List<Map<String, dynamic>>.from(transactionsResponse);

    // ----------------------------------------------------------
    // ORGANIZAR TRANSAÇÕES POR CLIENTE
    // ----------------------------------------------------------

    final transactionsByCustomer = <String, List<Map<String, dynamic>>>{};

    for (final transaction in transactions) {
      final customerId = transaction['customer_id']?.toString();

      if (customerId == null || customerId.isEmpty) {
        continue;
      }

      transactionsByCustomer.putIfAbsent(customerId, () => []).add(transaction);
    }

    // ----------------------------------------------------------
    // 4. BUSCAR PROMOÇÕES
    // ----------------------------------------------------------

    final promotionsResponse = await _supabase
        .from('promotions')
        .select(
          'id, title, description, type, '
          'points_required, discount_percentage, '
          'gift_description, active, starts_at, ends_at',
        )
        .eq('company_id', companyId);

    final promotions = List<Map<String, dynamic>>.from(promotionsResponse);

    // Mapa:
    // promotion_id -> promoção
    final promotionsMap = <String, Map<String, dynamic>>{};

    for (final promotion in promotions) {
      final promotionId = promotion['id']?.toString();

      if (promotionId == null || promotionId.isEmpty) {
        continue;
      }

      promotionsMap[promotionId] = promotion;
    }

    // ----------------------------------------------------------
    // 5. BUSCAR RESGATES
    //
    // Aqui conseguimos saber quais recompensas pertencem
    // individualmente a cada cliente.
    // ----------------------------------------------------------

    final redemptionsResponse = await _supabase
        .from('promotion_redemptions')
        .select(
          'id, customer_id, promotion_id, '
          'status, points_spent, created_at',
        )
        .eq('company_id', companyId)
        .order('created_at', ascending: false);

    final redemptions = List<Map<String, dynamic>>.from(redemptionsResponse);

    // ----------------------------------------------------------
    // ORGANIZAR RESGATES POR CLIENTE
    // ----------------------------------------------------------

    final redemptionsByCustomer = <String, List<Map<String, dynamic>>>{};

    for (final redemption in redemptions) {
      final customerId = redemption['customer_id']?.toString();

      if (customerId == null || customerId.isEmpty) {
        continue;
      }

      redemptionsByCustomer.putIfAbsent(customerId, () => []).add(redemption);
    }

    // ----------------------------------------------------------
    // 6. MONTAR RESULTADO
    // ----------------------------------------------------------

    final result = <Map<String, dynamic>>[];

    for (final profile in profiles) {
      final customerId = profile['id']?.toString();

      if (customerId == null || customerId.isEmpty) {
        continue;
      }

      // --------------------------------------------------------
      // PONTOS ATUAIS
      // --------------------------------------------------------

      final currentPoints = pointsByCustomer[customerId] ?? 0;

      // --------------------------------------------------------
      // PONTOS RECEBIDOS AO LONGO DO TEMPO
      // --------------------------------------------------------

      int pointsEarned = 0;

      final customerTransactions = transactionsByCustomer[customerId] ?? [];

      for (final transaction in customerTransactions) {
        if (transaction['type'] == 'earn') {
          pointsEarned += _toInt(transaction['points']);
        }
      }

      // --------------------------------------------------------
      // BENEFÍCIOS
      // --------------------------------------------------------

      final customerRedemptions = redemptionsByCustomer[customerId] ?? [];

      String? lastBenefitUsedAt;

      for (final redemption in customerRedemptions) {
        if (redemption['status'] != 'used') continue;

        final createdAt = redemption['created_at']?.toString();

        if (createdAt == null || createdAt.isEmpty) continue;

        final date = DateTime.tryParse(createdAt);
        if (date == null) continue;

        if (lastBenefitUsedAt == null) {
          lastBenefitUsedAt = createdAt;

          continue;
        }

        final currentLastDate = DateTime.tryParse(lastBenefitUsedAt);

        if (currentLastDate == null || date.isAfter(currentLastDate)) {
          lastBenefitUsedAt = createdAt;
        }
      }

      final availableBenefits = <Map<String, dynamic>>[];

      final usedBenefits = <Map<String, dynamic>>[];

      final cancelledBenefits = <Map<String, dynamic>>[];

      for (final redemption in customerRedemptions) {
        final promotionId = redemption['promotion_id']?.toString();

        final promotion = promotionId == null
            ? null
            : promotionsMap[promotionId];

        final title = promotion?['title'] ?? 'Recompensa';

        final benefit = {
          'id': redemption['id'],
          'promotion_id': promotionId,
          'title': title,
          'points_spent': _toInt(redemption['points_spent']),
          'created_at': redemption['created_at'],
          'expires_at': promotion?['ends_at'],
        };

        final status = redemption['status'];

        if (status == 'available') {
          availableBenefits.add(benefit);
        }

        if (status == 'used') {
          usedBenefits.add(benefit);
        }

        if (status == 'cancelled') {
          cancelledBenefits.add(benefit);
        }
      }

      // --------------------------------------------------------
      // RESULTADO DO CLIENTE
      // --------------------------------------------------------

      result.add({
        'id': customerId,

        'full_name': profile['full_name'],

        'whatsapp': profile['whatsapp'],

        // Saldo atual
        'points': currentPoints,

        'points_current': currentPoints,

        // Total recebido historicamente
        'points_earned': pointsEarned,

        'available_benefits': availableBenefits,

        'used_benefits': usedBenefits,

        'cancelled_benefits': cancelledBenefits,

        'last_benefit_used_at': lastBenefitUsedAt,
      });
    }

    // ----------------------------------------------------------
    // ORDENAR POR NOME
    // ----------------------------------------------------------

    result.sort(
      (a, b) => (a['full_name'] ?? '').toString().toLowerCase().compareTo(
        (b['full_name'] ?? '').toString().toLowerCase(),
      ),
    );

    return result;
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getDashboard() async {
    final companyId = await _getCompanyId();

    // ----------------------------------------------------------
    // EMPRESA
    // ----------------------------------------------------------

    final company = await _supabase
        .from('companies')
        .select('id, name, logo_url')
        .eq('id', companyId)
        .single();

    // ----------------------------------------------------------
    // CLIENTES
    // ----------------------------------------------------------

    final accounts = await _supabase
        .from('loyalty_accounts')
        .select('id, customer_id, points, left_at')
        .eq('company_id', companyId)
        .isFilter('left_at', null);

    final customers = accounts
        .map((item) => item['customer_id'])
        .where((id) => id != null)
        .toSet()
        .length;

    // ----------------------------------------------------------
    // TRANSAÇÕES
    // ----------------------------------------------------------

    final transactions = await _supabase
        .from('loyalty_transactions')
        .select('id, type, points, promotion_id')
        .eq('company_id', companyId);

    int pointsEarned = 0;

    final transactionCount = transactions.length;

    for (final transaction in transactions) {
      if (transaction['type'] == 'earn') {
        pointsEarned += _toInt(transaction['points']);
      }
    }

    // ----------------------------------------------------------
    // BENEFÍCIOS RESGATADOS
    // ----------------------------------------------------------

    final redemptions = await _supabase
        .from('promotion_redemptions')
        .select(
          'id, promotion_id, '
          'status, points_spent',
        )
        .eq('company_id', companyId);

    int availableBenefits = 0;
    int usedBenefits = 0;
    int cancelledBenefits = 0;

    for (final redemption in redemptions) {
      final status = redemption['status'];

      if (status == 'available') {
        availableBenefits++;
      }

      if (status == 'used') {
        usedBenefits++;
      }

      if (status == 'cancelled') {
        cancelledBenefits++;
      }
    }

    // ----------------------------------------------------------
    // PROMOÇÕES
    // ----------------------------------------------------------

    final promotions = await _supabase
        .from('promotions')
        .select('id, title, active')
        .eq('company_id', companyId);

    // ----------------------------------------------------------
    // CONTAGEM DE RESGATES POR PROMOÇÃO
    // ----------------------------------------------------------

    final Map<String, int> redemptionCount = {};

    for (final redemption in redemptions) {
      final promotionId = redemption['promotion_id']?.toString();

      if (promotionId == null) {
        continue;
      }

      redemptionCount[promotionId] = (redemptionCount[promotionId] ?? 0) + 1;
    }

    final popularPromotions = promotions.map((promotion) {
      final id = promotion['id'].toString();

      return {
        'id': id,
        'title': promotion['title'],
        'active': promotion['active'],
        'redemptions': redemptionCount[id] ?? 0,
      };
    }).toList();

    popularPromotions.sort(
      (a, b) => (b['redemptions'] as int).compareTo(a['redemptions'] as int),
    );

    // ----------------------------------------------------------
    // RESULTADO
    // ----------------------------------------------------------

    return {
      'company': company,

      'customers': customers,

      'points_earned': pointsEarned,

      'transactions': transactionCount,

      'redemptions': redemptions.length,

      'available_benefits': availableBenefits,

      'used_benefits': usedBenefits,

      'cancelled_benefits': cancelledBenefits,

      'popular_promotions': popularPromotions,
    };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
