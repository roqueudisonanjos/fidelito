import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final rows = await _supabase
        .from('user_notifications')
        .select('id, title, message, notification_type, read_at, created_at')
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<int> getUnreadCount() async {
    final rows = await _supabase
        .from('user_notifications')
        .select('id')
        .eq('user_id', _supabase.auth.currentUser!.id)
        .isFilter('read_at', null);
    return rows.length;
  }

  Future<void> markAsRead(String id) async {
    await _supabase
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', _supabase.auth.currentUser!.id);
  }
}
