import 'package:supabase_flutter/supabase_flutter.dart';

class PromotionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // PROMOÇÕES DISPONÍVEIS PARA O CLIENTE
  // ============================================================

  Future<List<Map<String, dynamic>>> getAvailablePromotions(
    String companyId,
  ) async {
    try {
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('company_id', companyId)
          .eq('active', true)
          .isFilter('deleted_at', null)
          .order('points_required');

      final now = DateTime.now().toUtc();
      return List<Map<String, dynamic>>.from(response).where((promotion) {
        final points = (promotion['points_required'] as num?)?.toInt() ?? 0;
        if (points <= 0) return false;
        final starts = promotion['starts_at'] == null
            ? null
            : DateTime.tryParse(promotion['starts_at'].toString())?.toUtc();
        final ends = promotion['ends_at'] == null
            ? null
            : DateTime.tryParse(promotion['ends_at'].toString())?.toUtc();
        return (starts == null || !now.isBefore(starts)) &&
            (ends == null || !now.isAfter(ends));
      }).toList();
    } catch (e) {
      throw Exception('Não foi possível carregar as promoções.');
    }
  }

  // ============================================================
  // TODAS AS PROMOÇÕES DA EMPRESA
  //
  // Usada pela CompanyHomePage.
  //
  // Aqui NÃO filtramos active=true porque a empresa precisa
  // conseguir visualizar também as promoções canceladas e
  // expiradas.
  // ============================================================

  Future<List<Map<String, dynamic>>> getCompanyPromotions(
    String companyId,
  ) async {
    try {
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('company_id', companyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Não foi possível carregar as promoções da empresa.');
    }
  }

  // ============================================================
  // BUSCAR UMA PROMOÇÃO
  // ============================================================

  Future<Map<String, dynamic>?> getPromotion(String promotionId) async {
    try {
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('id', promotionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Não foi possível carregar a recompensa.');
    }
  }

  // ============================================================
  // CRIAR PROMOÇÃO
  // ============================================================

  Future<Map<String, dynamic>> createPromotion({
    required String companyId,
    required String title,
    String? description,
    required String type,
    required int pointsRequired,
    double? discountPercentage,
    String? giftDescription,
    required DateTime startsAt,
    required DateTime endsAt,
    String? imageUrl,
  }) async {
    // ----------------------------------------------------------
    // Validações
    // ----------------------------------------------------------

    if (title.trim().isEmpty) {
      throw Exception('Informe o título da recompensa.');
    }

    if (type != 'discount' && type != 'gift') {
      throw Exception('Tipo de recompensa inválido.');
    }

    if (pointsRequired <= 0) {
      throw Exception('Recompensas devem exigir pelo menos 1 ponto. Promoções sem pontos devem ser criadas como ofertas.');
    }

    if (endsAt.isBefore(startsAt) || endsAt.isAtSameMomentAs(startsAt)) {
      throw Exception(
        'A data de validade deve ser posterior à data de início.',
      );
    }

    if (type == 'discount') {
      if (discountPercentage == null ||
          discountPercentage <= 0 ||
          discountPercentage > 100) {
        throw Exception(
          'Informe um percentual de desconto válido entre 1 e 100.',
        );
      }
    }

    if (type == 'gift') {
      if (giftDescription == null || giftDescription.trim().isEmpty) {
        throw Exception('Informe a descrição do brinde.');
      }
    }

    // ----------------------------------------------------------
    // Dados que serão enviados ao Supabase
    // ----------------------------------------------------------

    final data = <String, dynamic>{
      'company_id': companyId,
      'title': title.trim(),
      'description': _nullableText(description),
      'type': type,
      'points_required': pointsRequired,
      'discount_percentage': type == 'discount' ? discountPercentage : null,
      'gift_description': type == 'gift'
          ? _nullableText(giftDescription)
          : null,
      'active': true,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'image_url': imageUrl,
    };

    try {
      final response = await _supabase
          .from('promotions')
          .insert(data)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Não foi possível criar a recompensa.');
    }
  }

  // ============================================================
  // ATUALIZAR PROMOÇÃO
  // ============================================================

  Future<Map<String, dynamic>> updatePromotion({
    required String promotionId,
    required String companyId,
    required String title,
    String? description,
    required String type,
    required int pointsRequired,
    double? discountPercentage,
    String? giftDescription,
    required DateTime startsAt,
    required DateTime endsAt,
    String? imageUrl,
  }) async {
    // ----------------------------------------------------------
    // Validações
    // ----------------------------------------------------------

    if (title.trim().isEmpty) {
      throw Exception('Informe o título da recompensa.');
    }

    if (type != 'discount' && type != 'gift') {
      throw Exception('Tipo de recompensa inválido.');
    }

    if (pointsRequired <= 0) {
      throw Exception('Recompensas devem exigir pelo menos 1 ponto. Promoções sem pontos devem ser criadas como ofertas.');
    }

    if (endsAt.isBefore(startsAt) || endsAt.isAtSameMomentAs(startsAt)) {
      throw Exception(
        'A data de validade deve ser posterior à data de início.',
      );
    }

    if (type == 'discount') {
      if (discountPercentage == null ||
          discountPercentage <= 0 ||
          discountPercentage > 100) {
        throw Exception(
          'Informe um percentual de desconto válido entre 1 e 100.',
        );
      }
    }

    if (type == 'gift') {
      if (giftDescription == null || giftDescription.trim().isEmpty) {
        throw Exception('Informe a descrição do brinde.');
      }
    }

    // ----------------------------------------------------------
    // Atualização
    //
    // O company_id também é usado no filtro para evitar que
    // uma empresa altere uma promoção de outra empresa.
    // ----------------------------------------------------------

    final data = <String, dynamic>{
      'title': title.trim(),
      'description': _nullableText(description),
      'type': type,
      'points_required': pointsRequired,
      'discount_percentage': type == 'discount' ? discountPercentage : null,
      'gift_description': type == 'gift'
          ? _nullableText(giftDescription)
          : null,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'image_url': imageUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _supabase
          .from('promotions')
          .update(data)
          .eq('id', promotionId)
          .eq('company_id', companyId)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Não foi possível atualizar a recompensa.');
    }
  }

  // ============================================================
  // CANCELAR PROMOÇÃO
  //
  // Não apagamos o registro.
  //
  // active = false
  //
  // Assim:
  // - o cliente deixa de visualizar;
  // - a empresa continua vendo o histórico;
  // - promoções já resgatadas continuam tendo referência;
  // - podemos diferenciar "cancelado" de "apagado".
  // ============================================================

  Future<void> cancelPromotion(String promotionId) async {
    try {
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

      final companyId = company['id'];

      await _supabase
          .from('promotions')
          .update({
            'active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', promotionId)
          .eq('company_id', companyId);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
  // ============================================================
  // REATIVAR PROMOÇÃO
  //
  // Útil caso a empresa cancele por engano.
  //
  // Só permite reativar se a data final ainda não passou.
  // ============================================================

  Future<void> activatePromotion({
    required String promotionId,
    required String companyId,
  }) async {
    try {
      final promotion = await _supabase
          .from('promotions')
          .select('ends_at')
          .eq('id', promotionId)
          .eq('company_id', companyId)
          .maybeSingle();

      if (promotion == null) {
        throw Exception('Recompensa não encontrado.');
      }

      final endsAt = DateTime.tryParse(promotion['ends_at'].toString());

      if (endsAt == null) {
        throw Exception('A data de validade da recompensa é inválida.');
      }

      if (!endsAt.isAfter(DateTime.now())) {
        throw Exception('Esta recompensa já expirou e não pode ser reativada.');
      }

      await _supabase
          .from('promotions')
          .update({
            'active': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', promotionId)
          .eq('company_id', companyId);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception('Não foi possível reativar a recompensa.');
    }
  }

  // ============================================================
  // EXCLUIR PROMOÇÃO
  //
  // A exclusão é lógica: a função no banco marca a recompensa como
  // inativa e preenchida em deleted_at, preservando o histórico de resgates.
  // ============================================================

  Future<void> deletePromotion(String promotionId) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final response = await _supabase.rpc(
        'delete_promotion',
        params: {'p_promotion_id': promotionId},
      );

      if (response is Map && response['success'] != true) {
        throw Exception('Não foi possível excluir a recompensa.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
  // ============================================================
  // RESGATAR PROMOÇÃO
  //
  // Mantém compatibilidade com:
  //
  // CustomerHomePage
  // PromotionsPage
  //
  // que já fazem:
  //
  // _service.redeemPromotion(promotionId)
  //
  // A RPC deve ser responsável pela operação transacional:
  // - verificar pontos;
  // - verificar validade;
  // - debitar pontos;
  // - registrar o resgate;
  // - retornar o novo saldo.
  // ============================================================

  Future<Map<String, dynamic>> redeemPromotion(String promotionId) async {
    try {
      final response = await _supabase.rpc(
        'redeem_promotion',
        params: {'p_promotion_id': promotionId},
      );

      if (response == null) {
        throw Exception('Não foi possível realizar o resgate.');
      }

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is List &&
          response.isNotEmpty &&
          response.first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.first);
      }

      throw Exception('Resposta inválida ao realizar o resgate.');
    } catch (e) {
      throw Exception(_cleanErrorMessage(e));
    }
  }

  // ============================================================
  // BENEFÍCIOS RESGATADOS PELO CLIENTE
  //
  // Mantém compatibilidade com possíveis chamadas existentes.
  //
  // OBS:
  // Se sua tabela de resgates tiver outro nome/estrutura,
  // mantenha o BenefitService atual para essa parte.
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyRedemptions() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final response = await _supabase
          .from('benefit_redemptions')
          .select('''
            *,
            promotions (
              id,
              company_id,
              title,
              description,
              type,
              points_required,
              discount_percentage,
              gift_description,
              active,
              starts_at,
              ends_at
            ),
            companies (
              id,
              name,
              logo_url
            )
          ''')
          .eq('customer_id', user.id)
          .order('redeemed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Não foi possível carregar suas recompensas.');
    }
  }

  // ============================================================
  // MÉTODOS AUXILIARES
  // ============================================================

  String? _nullableText(String? value) {
    if (value == null) {
      return null;
    }

    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  String _cleanErrorMessage(dynamic error) {
    String message = error.toString();

    message = message.replaceFirst('Exception: ', '');

    if (message.contains('Pontos insuficientes')) {
      return 'Você não possui pontos suficientes.';
    }

    if (message.contains('promotion_not_found')) {
      return 'Esta recompensa não está mais disponível.';
    }

    if (message.contains('promotion_expired')) {
      return 'Esta recompensa já expirou.';
    }

    if (message.contains('promotion_inactive')) {
      return 'Esta recompensa foi cancelada.';
    }

    if (message.contains('not enough points')) {
      return 'Você não possui pontos suficientes.';
    }

    return message;
  }
}
