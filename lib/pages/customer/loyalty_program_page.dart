import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/promotion_service.dart';
import '../../services/share_service.dart';
import '../../widgets/floating_image_card.dart';
import '../../widgets/fullscreen_image_view.dart';

class LoyaltyProgramPage extends StatefulWidget {
  const LoyaltyProgramPage({super.key, required this.company});

  final Map<String, dynamic> company;

  @override
  State<LoyaltyProgramPage> createState() => _LoyaltyProgramPageState();
}

class _LoyaltyProgramPageState extends State<LoyaltyProgramPage> {
  final _service = LoyaltyProgramService();
  final _promotionService = PromotionService();

  bool _loading = true;
  int _points = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _promotions = [];
  String? _error;

  static const double _cardWidth = 270;
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(12, 12, 12, 8);
  static const int _descriptionMaxChars = 80;

  String get _companyId => widget.company['id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _service.getMyPrograms();
      final own = account.where((a) => a['company_id'].toString() == _companyId).toList();
      if (own.isEmpty) {
        throw Exception('Você ainda não participa desta fidelidade.');
      }
      final companyIsActive = widget.company['active'] == true;
      final results = await Future.wait<dynamic>([
        _service.getCompanyTransactions(_companyId),
        companyIsActive
            ? _service.getCompanyPromotions(_companyId)
            : Future.value(<Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _points = (own.first['points'] as num?)?.toInt() ?? 0;
        _transactions = results[0];
        _promotions = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _leaveProgram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair deste programa?'),
        content: const Text(
          'Ao sair, você perderá imediatamente todos os pontos acumulados nesta empresa. '
          'O histórico e as recompensas já resgatados serão mantidos, mas o saldo não poderá ser recuperado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar participando'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair e perder pontos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.leaveProgram(_companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você saiu do programa de fidelidade.')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _redeem(Map<String, dynamic> promotion) async {
    final requiredPoints = (promotion['points_required'] as num?)?.toInt() ?? 0;
    if (requiredPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensas sem pontos agora são ofertas.')),
      );
      return;
    }
    if (_points < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não possui pontos suficientes.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar resgate'),
        content: Text('Trocar $requiredPoints pontos por "${promotion['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final result = await _promotionService.redeemPromotion(promotion['id'].toString());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recompensa resgatada!'),
          content: Text(
            '${result['title']}\nPontos utilizados: ${result['points_spent']}\nNovo saldo: ${result['new_balance']} pontos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---------- Helpers dos cards ----------

  String _limitText(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= _descriptionMaxChars) return trimmed;
    return '${trimmed.substring(0, _descriptionMaxChars).trimRight()}…';
  }

  DateTime? _endDate(Map<String, dynamic> item) {
    for (final key in ['ends_at', 'valid_until', 'expires_at']) {
      final value = item[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final date = DateTime.tryParse(value);
      if (date != null) return date.toLocal();
    }
    return null;
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _rewardHeader(Map<String, dynamic> promotion) {
    final logo = widget.company['logo_url']?.toString() ?? '';
    final name = widget.company['name']?.toString() ?? 'Empresa';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 12) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Compartilhar recompensa',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: () => ShareService.sharePromotion(
            companyName: name,
            title: promotion['title']?.toString() ?? 'Recompensa',
            type: promotion['type']?.toString() ?? '',
            discountPercentage: promotion['discount_percentage']?.toString(),
            giftDescription: promotion['gift_description']?.toString(),
            description: promotion['description']?.toString(),
            companyLogoUrl: logo,
            companyId: _companyId,
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  Widget _rewardActions(Map<String, dynamic> promotion, bool canRedeem, int points) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: canRedeem
                ? Colors.green.withValues(alpha: .12)
                : Colors.grey.withValues(alpha: .12),
          ),
          child: Text(
            '$points pts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: canRedeem ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: canRedeem ? () => _redeem(promotion) : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(canRedeem ? 'Resgatar recompensa' : 'Pontos insuficientes'),
            ),
          ),
        ),
      ],
    );
  }

  List<FloatBlock> _rewardBlocks(Map<String, dynamic> promotion) {
    final points = (promotion['points_required'] as num?)?.toInt() ?? 0;
    final canRedeem = points > 0 && _points >= points;
    final type = promotion['type']?.toString();
    final discount = promotion['discount_percentage'];
    final gift = promotion['gift_description']?.toString().trim() ?? '';
    final rewardText = type == 'discount' && discount != null
        ? '${(discount as num).toStringAsFixed(0)}% de desconto'
        : (gift.isNotEmpty ? gift : 'Recompensa especial');
    final description = _limitText(promotion['description']?.toString() ?? '');
    final endDate = _endDate(promotion);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;

    return [
      FloatBlock.widget(_rewardHeader(promotion), height: 36, spacing: 6),
      FloatBlock.text(
        promotion['title']?.toString() ?? 'Recompensa',
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      FloatBlock.text(
        rewardText,
        bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
        spacing: 6,
        maxLines: 1,
        fullWidth: true,
      ),
      if (description.isNotEmpty)
        FloatBlock.text(
          description,
          bodyStyle.copyWith(fontSize: 13),
          spacing: 6,
          maxLines: 3,
        ),
      if (endDate != null)
        FloatBlock.text(
          'Válido até ${_formatDateOnly(endDate)}',
          bodyStyle.copyWith(
            fontSize: 13,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
          spacing: 6,
          maxLines: 1,
        ),
      FloatBlock.text(
        canRedeem
            ? 'Você já pode resgatar esta recompensa.'
            : 'Faltam ${points - _points} pontos nesta empresa.',
        bodyStyle.copyWith(fontSize: 13, color: canRedeem ? Colors.green : Colors.grey),
        spacing: 8,
        maxLines: 2,
      ),
      FloatBlock.widget(_rewardActions(promotion, canRedeem, points), height: 40),
    ];
  }

  Widget _buildRewardsSection() {
    final visible = _promotions.take(10).toList();
    final heights = visible
        .map(
          (promotion) => FloatingImageCard.measureHeight(
            context,
            blocks: _rewardBlocks(promotion),
            width: _cardWidth,
            padding: _cardPadding,
          ),
        )
        .toList();
    final listHeight = heights.fold<double>(0, (acc, h) => h > acc ? h : acc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recompensas disponíveis',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Esta empresa não possui recompensas disponíveis no momento.'),
            ),
          )
        else
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: _cardWidth,
                height: heights[index],
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  child: FloatingImageCard(
                    padding: _cardPadding,
                    blocks: _rewardBlocks(visible[index]),
                  ),
                ),
              ),
            ),
          ),
        if (widget.company['active'] == true)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(
                '/customer/promotions?companyId=$_companyId',
              ),
              child: const Text('Ver todos'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final logoUrl = (company['logo_url'] ?? '').toString().trim();
    final location = [
      company['city'],
      company['state'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' - ');

    return Scaffold(
      appBar: AppBar(title: Text(company['name']?.toString() ?? 'Fidelidade')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: logoUrl.isEmpty
                          ? null
                          : () => showFullscreenImage(context, logoUrl),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundImage: (company['logo_url'] ?? '').toString().isNotEmpty
                            ? NetworkImage(company['logo_url'].toString())
                            : null,
                        child: (company['logo_url'] ?? '').toString().isNotEmpty
                            ? null
                            : const Icon(Icons.storefront_outlined, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((company['description'] ?? '').toString().trim().isNotEmpty)
                    Text(company['description'].toString()),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        location,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final left = await context.push<bool>(
                          '/customer/company-details',
                          extra: <String, dynamic>{...company, 'joined': true},
                        );
                        if (!context.mounted) return;
                        if (left == true) context.pop(true);
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Ver empresa'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, size: 36),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Seu saldo nesta empresa'),
                              Text(
                                '$_points pontos',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRewardsSection(),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _leaveProgram,
                    icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                    label: const Text('Não quero mais participar deste programa'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Histórico de pontos',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('Nenhuma movimentação nesta fidelidade ainda.'),
                    ),
                  ..._transactions.take(5).map((t) {
                    final pts = (t['points'] as num?)?.toInt() ?? 0;
                    final date = DateTime.tryParse(t['created_at']?.toString() ?? '')?.toLocal();
                    final dateText = date == null
                        ? ''
                        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(pts >= 0 ? Icons.add : Icons.remove),
                      ),
                      title: Text(t['description']?.toString() ?? 'Movimentação'),
                      subtitle: Text(dateText),
                      trailing: Text(
                        '${pts > 0 ? '+' : ''}$pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pts >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/customer/loyalty-history/$_companyId',
                        extra: widget.company,
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text('Ver histórico completo'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}