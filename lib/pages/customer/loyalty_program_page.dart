import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/promotion_service.dart';

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
  Set<String> _redeemedPromotionIds = {};
  String? _error;
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
      final own = account
          .where((a) => a['company_id'].toString() == _companyId)
          .toList();
      if (own.isEmpty) {
        throw Exception('Você ainda não participa desta fidelidade.');
      }
      final companyIsActive = widget.company['active'] == true;
      final results = await Future.wait<dynamic>([
        _service.getCompanyTransactions(_companyId),
        companyIsActive
            ? _service.getCompanyPromotions(_companyId)
            : Future.value(<Map<String, dynamic>>[]),
        _promotionService.getMyRedeemedPromotionIds(companyId: _companyId),
      ]);
      if (!mounted) return;
      setState(() {
        _points = (own.first['points'] as num?)?.toInt() ?? 0;
        _transactions = results[0];
        _promotions = results[1] as List<Map<String, dynamic>>;
        _redeemedPromotionIds = results[2] as Set<String>;
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
        content: Text(
          requiredPoints == 0
              ? 'Resgatar gratuitamente "${promotion['title']}"?'
              : 'Trocar $requiredPoints pontos por "${promotion['title']}"?',
        ),
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
      final result = await _promotionService.redeemPromotion(
        promotion['id'].toString(),
      );
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

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
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
                    child: CircleAvatar(
                      radius: 34,
                      backgroundImage:
                          (company['logo_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(company['logo_url'].toString())
                          : null,
                      child: (company['logo_url'] ?? '').toString().isNotEmpty
                          ? null
                          : const Icon(Icons.storefront_outlined, size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((company['description'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(company['description'].toString()),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        location,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recompensas disponíveis',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (company['active'] == true)
                        TextButton(
                          onPressed: () => context.push(
                            '/customer/promotions?companyId=$_companyId',
                          ),
                          child: const Text('Ver todos'),
                        ),
                    ],
                  ),
                  if (_promotions.isEmpty)
                    const Text(
                      'Esta empresa não possui recompensas disponíveis no momento.',
                    ),
                  ..._promotions.take(4).map((p) {
                    final cost = (p['points_required'] as num?)?.toInt() ?? 0;
                    final alreadyRedeemedFree =
                        cost == 0 &&
                        _redeemedPromotionIds.contains(p['id'].toString());
                    final canRedeem = !alreadyRedeemedFree && _points >= cost;
                    final reward = p['type'] == 'discount'
                        ? '${p['discount_percentage'] ?? ''}% de desconto'
                        : (p['gift_description'] ?? 'Brinde').toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((p['image_url'] ?? '').toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  p['image_url'].toString(),
                                  height: 110,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Text(
                              p['title']?.toString() ?? 'Recompensa',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(reward),
                            if ((p['description'] ?? '').toString().isNotEmpty)
                              Text(p['description'].toString()),
                            const SizedBox(height: 8),
                            Text(cost == 0 ? 'Grátis • sem pontos' : '$cost pontos'),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonal(
                                onPressed: canRedeem ? () => _redeem(p) : null,
                                style: FilledButton.styleFrom(
                                  disabledBackgroundColor: alreadyRedeemedFree
                                      ? Colors.grey.shade400
                                      : null,
                                  disabledForegroundColor: alreadyRedeemedFree
                                      ? Colors.white
                                      : null,
                                ),
                                child: Text(
                                  alreadyRedeemedFree
                                      ? 'Recompensa resgatada'
                                      : 'Resgatar',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'Histórico de pontos',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Nenhuma movimentação nesta fidelidade ainda.',
                      ),
                    ),
                  ..._transactions.map((t) {
                    final pts = (t['points'] as num?)?.toInt() ?? 0;
                    final date = DateTime.tryParse(
                      t['created_at']?.toString() ?? '',
                    )?.toLocal();
                    final dateText = date == null
                        ? ''
                        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(pts >= 0 ? Icons.add : Icons.remove),
                      ),
                      title: Text(
                        t['description']?.toString() ?? 'Movimentação',
                      ),
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
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _leaveProgram,
                    icon: const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Não quero mais participar deste programa',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
