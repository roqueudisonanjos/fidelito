import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _supabase.functions.invoke(
      'admin-console',
      body: body,
    );
    final data = response.data;
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      if (response.status >= 400 || result['error'] != null) {
        throw Exception(
          result['error']?.toString() ??
              'Não foi possível concluir a operação.',
        );
      }
      return result;
    }
    throw Exception('Resposta inválida do servidor administrativo.');
  }

  Future<bool> checkAccess() async {
    try {
      final result = await _invoke({'action': 'check_access'});
      return result['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers({String query = ''}) async {
    final result = await _invoke({
      'action': 'list_customers',
      'query': query.trim(),
    });
    final rows = result['customers'];
    if (rows is! List) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCompanies({String query = ''}) async {
    final result = await _invoke({
      'action': 'list_companies',
      'query': query.trim(),
    });
    final rows = result['companies'];
    if (rows is! List) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<String> generateRecoveryLink(String userId) async {
    final result = await _invoke({
      'action': 'generate_recovery_link',
      'user_id': userId,
    });
    final link = result['recovery_link']?.toString();
    if (link == null || link.isEmpty) {
      throw Exception('O servidor não retornou o link de recuperação.');
    }
    return link;
  }

  Future<String> generateCompanyRecoveryLink(String companyId) async {
    final result = await _invoke({
      'action': 'generate_company_recovery_link',
      'company_id': companyId,
    });
    final link = result['recovery_link']?.toString();
    if (link == null || link.isEmpty) {
      throw Exception(
        'O servidor não retornou o link de recuperação do responsável.',
      );
    }
    return link;
  }

  Future<void> deleteCustomerAccount(String customerId) async {
    await _invoke({
      'action': 'delete_customer_account_admin',
      'user_id': customerId,
    });
  }

  Future<void> deleteCompanyAccount(String companyId) async {
    await _invoke({
      'action': 'delete_company_account_admin',
      'company_id': companyId,
    });
  }

  Future<void> setCompanyActive({
    required String companyId,
    required bool active,
  }) async {
    await _invoke({
      'action': 'set_company_active',
      'company_id': companyId,
      'active': active,
    });
  }
}
