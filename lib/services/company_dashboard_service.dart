import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyDashboardData {
  final String companyId;
  final String companyName;
  final String? companyDescription;
  final String? companyLogoUrl;

  final int benefitsUsed;
  final int customersServed;

  final int totalQrCodes;
  final int activeQrCodes;
  final int usedQrCodes;

  const CompanyDashboardData({
    required this.companyId,
    required this.companyName,
    this.companyDescription,
    this.companyLogoUrl,
    required this.benefitsUsed,
    required this.customersServed,
    required this.totalQrCodes,
    required this.activeQrCodes,
    required this.usedQrCodes,
  });
}

class CompanyDashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<CompanyDashboardData> loadDashboard() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    // ============================================================
    // 1. BUSCAR A EMPRESA DO USUÁRIO LOGADO
    // ============================================================

    final company = await _supabase
        .from('companies')
        .select(
          'id, name, description, logo_url',
        )
        .eq('owner_id', user.id)
        .eq('active', true)
        .maybeSingle();

    if (company == null) {
      throw Exception(
        'Nenhuma empresa ativa foi encontrada para este usuário.',
      );
    }

    final companyId = company['id'].toString();

    // ============================================================
    // 2. BUSCAR TRANSAÇÕES DA EMPRESA
    // ============================================================

    final transactions = await _supabase
        .from('loyalty_transactions')
        .select(
          'id, customer_id, type, points, promotion_id, created_at',
        )
        .eq('company_id', companyId);

    // ============================================================
    // 3. CLIENTES ATENDIDOS
    //
    // Consideramos clientes únicos que possuem alguma
    // transação com a empresa.
    // ============================================================

    final customerIds = <String>{};

    for (final transaction in transactions) {
      final customerId = transaction['customer_id'];

      if (customerId != null) {
        customerIds.add(
          customerId.toString(),
        );
      }
    }

    // ============================================================
    // 4. BENEFÍCIOS UTILIZADOS
    //
    // redeem = resgate de benefício/pontos.
    // ============================================================

    int benefitsUsed = 0;

    for (final transaction in transactions) {
      final type = transaction['type']?.toString();

      if (type == 'redeem') {
        benefitsUsed++;
      }
    }

    // ============================================================
    // 5. QR CODES
    // ============================================================

    final qrCodes = await _supabase
        .from('qr_codes')
        .select(
          'id, active, used_at',
        )
        .eq('company_id', companyId);

    int activeQrCodes = 0;
    int usedQrCodes = 0;

    for (final qr in qrCodes) {
      if (qr['active'] == true) {
        activeQrCodes++;
      }

      if (qr['used_at'] != null) {
        usedQrCodes++;
      }
    }

    // ============================================================
    // 6. RETORNAR DADOS
    // ============================================================

    return CompanyDashboardData(
      companyId: companyId,

      companyName:
          company['name']?.toString() ?? 'Empresa',

      companyDescription:
          company['description']?.toString(),

      companyLogoUrl:
          company['logo_url']?.toString(),

      benefitsUsed: benefitsUsed,

      customersServed: customerIds.length,

      totalQrCodes: qrCodes.length,

      activeQrCodes: activeQrCodes,

      usedQrCodes: usedQrCodes,
    );
  }
}