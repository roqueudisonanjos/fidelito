import 'package:supabase_flutter/supabase_flutter.dart';

class LoyaltyService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<Map<String, dynamic>> redeemQrCode(
    String code,
  ) async {
    final result = await _supabase.rpc(
      'redeem_qr_code',
      params: {
        'p_code': code,
      },
    );

    return Map<String, dynamic>.from(result);
  }
}