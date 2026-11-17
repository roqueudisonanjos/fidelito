import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getCompanyReport({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
    required String type,
  }) async {
    if (companyId.isEmpty || companyId == 'null') {
      throw Exception('Empresa não informada.');
    }

    var query = _supabase
        .from('loyalty_transactions')
        .select('''
          id,
          customer_id,
          company_id,
          type,
          points,
          description,
          created_at
          ''')
        .eq('company_id', companyId);

    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);

      query = query.gte('created_at', start.toIso8601String());
    }

    if (endDate != null) {
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ).add(const Duration(days: 1));

      query = query.lt('created_at', end.toIso8601String());
    }

    if (type != 'all') {
      query = query.eq('type', type);
    }

    final response = await query.order('created_at', ascending: false);

    final transactions = List<Map<String, dynamic>>.from(response);

    // --------------------------------------------------
    // BUSCAR OS NOMES DOS CLIENTES
    // --------------------------------------------------

    final Map<String, String> customerNames = {};
    final Map<String, String> customerAvatars = {};

    for (final transaction in transactions) {
      final customerId = transaction['customer_id']?.toString();

      if (customerId == null || customerId.isEmpty || customerId == 'null') {
        continue;
      }

      // Evita consultar o mesmo cliente várias vezes.
      if (customerNames.containsKey(customerId)) {
        continue;
      }

      final profile = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', customerId)
          .maybeSingle();

      if (profile != null) {
        final name = profile['full_name'];

        if (name != null && name.toString().trim().isNotEmpty) {
          customerNames[customerId] = name.toString();
        }
        final avatar = profile['avatar_url']?.toString();
        if (avatar != null && avatar.isNotEmpty)
          customerAvatars[customerId] = avatar;
      }
    }

    // --------------------------------------------------
    // ADICIONAR O NOME EM CADA TRANSAÇÃO
    // --------------------------------------------------

    for (final transaction in transactions) {
      final customerId = transaction['customer_id']?.toString();

      if (customerId == null) {
        transaction['customer_name'] = 'Cliente';
        continue;
      }

      transaction['customer_name'] = customerNames[customerId] ?? 'Cliente';
      transaction['customer_avatar_url'] = customerAvatars[customerId];
    }

    // --------------------------------------------------
    // CALCULAR RESUMO
    // --------------------------------------------------

    int totalTransactions = transactions.length;

    int totalPoints = 0;

    int totalEarned = 0;

    int totalSpent = 0;

    for (final transaction in transactions) {
      final points = (transaction['points'] ?? 0) as int;

      totalPoints += points.abs();

      final transactionType = transaction['type']?.toString();

      if (transactionType == 'earn') {
        totalEarned += points.abs();
      } else if (transactionType == 'redeem') {
        totalSpent += points.abs();
      }
    }

    return {
      'transactions': transactions,

      'total_transactions': totalTransactions,

      'total_points': totalPoints,

      'total_earned': totalEarned,

      'total_spent': totalSpent,
    };
  }
}
