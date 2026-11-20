import 'package:supabase_flutter/supabase_flutter.dart';

class StaticQrRequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final result = await _supabase.rpc('get_company_qr_point_requests');
    if (result is! List) return [];
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }


  Future<void> approve(String requestId) async {
    await _supabase.rpc('approve_static_qr_points_request', params: {'p_request_id': requestId});
  }

  Future<void> reject(String requestId) async {
    await _supabase.rpc('reject_static_qr_points_request', params: {'p_request_id': requestId});
  }
}
