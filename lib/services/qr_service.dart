import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qr_code.dart';

class QrService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<QrCodeModel> createQrCode({required int points, int expirationMinutes = 10}) async {
    if (_supabase.auth.currentUser == null) throw Exception('Usuário não autenticado.');
    final response = await _supabase.rpc('create_qr_code', params: {
      'p_points': points,
      'p_expiration_minutes': expirationMinutes,
    });
    if (response is List && response.isNotEmpty) return QrCodeModel.fromMap(Map<String, dynamic>.from(response.first));
    if (response is Map) return QrCodeModel.fromMap(Map<String, dynamic>.from(response));
    throw Exception('Não foi possível gerar o QR Code.');
  }


  Future<QrCodeModel> createStaticQrCode({required int points}) async {
    if (_supabase.auth.currentUser == null) throw Exception('Usuário não autenticado.');
    final response = await _supabase.rpc('create_static_qr_code', params: {'p_points': points});
    if (response is Map) return QrCodeModel.fromMap(Map<String, dynamic>.from(response));
    if (response is List && response.isNotEmpty) return QrCodeModel.fromMap(Map<String, dynamic>.from(response.first));
    throw Exception('Não foi possível gerar o QR Code permanente.');
  }


  Future<Map<String, dynamic>> redeemQrCode(String code) async {
    if (code.trim().isEmpty) throw Exception('QR Code inválido.');
    try {
      final response = await _supabase.rpc('redeem_qr_code', params: {'p_code': code.trim()});
      if (response is! Map) throw Exception('Resposta inválida do servidor.');
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Não foi possível processar o QR Code.');
    }
  }
}
