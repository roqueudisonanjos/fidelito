import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String whatsapp,
    List<String> customerInterests = const [],
    String? businessCategory,
  }) {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': name,
        'phone': whatsapp,
        'role': role,
        'customer_interests': customerInterests,
        'business_category': businessCategory,
      },
    );
  }

  Future<void> logout() {
    return _supabase.auth.signOut();
  }

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  Future<String?> getCurrentUserRole() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    // O status de administrador é validado no servidor, por uma tabela
    // inacessível ao cliente. Nunca confiamos em metadados editáveis pelo usuário.
    try {
      final adminResponse = await _supabase.functions.invoke(
        'admin-console',
        body: {'action': 'check_access'},
      );
      final adminData = adminResponse.data;
      if (adminData is Map && adminData['is_admin'] == true) {
        return 'admin';
      }
    } catch (_) {
      // Mantém o login de clientes/empresas funcionando mesmo se a função
      // administrativa ainda não estiver implantada.
    }

    final response = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return response?['role'] as String?;
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }
}
