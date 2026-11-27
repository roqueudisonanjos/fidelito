import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyOfferService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPublicOffers({String? companyId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    var query = _db.from('company_offers').select('*, companies!inner(id,name,logo_url,city,state,category,active)')
        .eq('active', true);
    query = query.eq('companies.active', true);
    if (companyId != null && companyId.isNotEmpty) query = query.eq('company_id', companyId);
    final rows = await query;
    return List<Map<String, dynamic>>.from(rows).where((o) {
      final start = DateTime.tryParse('${o['starts_at'] ?? ''}');
      final end = DateTime.tryParse('${o['ends_at'] ?? ''}');
      final current = DateTime.parse(now);
      return (start == null || !current.isBefore(start.toUtc())) &&
          (end == null || !current.isAfter(end.toUtc()));
    }).toList();
  }


  Future<List<Map<String, dynamic>>> getMyOffers(String companyId) async {
    final rows = await _db.from('company_offers').select().eq('company_id', companyId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }


  Future<String> getOwnedCompanyId() async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final row = await _db.from('companies').select('id').eq('owner_id', user.id).maybeSingle();
    if (row == null) throw Exception('Empresa não encontrada.');
    return row['id'].toString();
  }


  Future<void> saveOffer({String? id, required String companyId, required String title,
      String? description, String? imageUrl, List<String>? mediaUrls, required DateTime start, required DateTime end,
      required bool active}) async {
    if (title.trim().isEmpty) throw Exception('Informe o título da oferta.');
    if (!end.isAfter(start)) throw Exception('A data final deve ser posterior à inicial.');
    final payload = {
      'title': title.trim(), 'description': (description?.trim().isEmpty ?? true) ? null : description?.trim(),
      'image_url': (mediaUrls != null && mediaUrls.isNotEmpty) ? mediaUrls.first : ((imageUrl?.trim().isEmpty ?? true) ? null : imageUrl?.trim()),
      'media_urls': mediaUrls ?? ((imageUrl?.trim().isNotEmpty ?? false) ? [imageUrl!.trim()] : []),
      'starts_at': start.toUtc().toIso8601String(), 'ends_at': end.toUtc().toIso8601String(),
      'active': active, 'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await _db.from('company_offers').insert({...payload, 'company_id': companyId});
    } else {
      await _db.from('company_offers').update(payload).eq('id', id).eq('company_id', companyId);
    }
  }


  Future<void> toggleActive(String id, bool active, {required String companyId}) async {
    await _db.from('company_offers').update({'active': active, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('company_id', companyId);
  }


  Future<void> deleteOffer(String id, {required String companyId}) async {
    await _db.from('company_offers').delete().eq('id', id).eq('company_id', companyId);
  }
}
