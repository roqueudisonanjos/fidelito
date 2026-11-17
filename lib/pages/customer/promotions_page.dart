import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/promotion_service.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, required this.companyId});

  final String companyId;

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PromotionService _service = PromotionService();

  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> _promotions = [];

  int _points = 0;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final account = await Supabase.instance.client
          .from('loyalty_accounts')
          .select('points')
          .eq('customer_id', user.id)
          .eq('company_id', widget.companyId)
          .isFilter('left_at', null)
          .maybeSingle();

      if (account == null) {
        throw Exception(
          'Você não participa do programa de fidelidade desta empresa.',
        );
      }

      final promotions = await _service.getAvailablePromotions(
        widget.companyId,
      );

      if (!mounted) return;

      setState(() {
        _points = account['points'] ?? 0;

        _promotions = promotions;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _redeem(Map<String, dynamic> promotion) async {
    final pointsRequired = promotion['points_required'] as int;

    if (_points < pointsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não possui pontos suficientes.')),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar resgate'),
          content: Text(
            'Você deseja trocar '
            '$pointsRequired pontos por '
            '"${promotion['title']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Resgatar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _service.redeemPromotion(promotion['id']);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Resgate realizado! 🎉'),
            content: Text(
              '${result['title']}\n\n'
              'Pontos utilizados: '
              '${result['points_spent']}\n\n'
              'Novo saldo: '
              '${result['new_balance']} pontos.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promoções')),
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
              onRefresh: _loadData,
              child: _promotions.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('Nenhuma promoção disponível.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _promotions.length,
                      itemBuilder: (context, index) {
                        final promotion = _promotions[index];

                        final title = promotion['title'];

                        final description = promotion['description'];

                        final pointsRequired = promotion['points_required'];

                        final type = promotion['type'];

                        final discount = promotion['discount_percentage'];

                        final gift = promotion['gift_description'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),

                                const SizedBox(height: 8),

                                if (description != null) Text(description),

                                const SizedBox(height: 12),

                                if (type == 'discount' && discount != null)
                                  Text(
                                    '$discount% de desconto',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                if (type == 'gift' && gift != null)
                                  Text(
                                    gift,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                Text(
                                  '$pointsRequired pontos',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _points >= pointsRequired
                                        ? () => _redeem(promotion)
                                        : null,
                                    child: const Text('Resgatar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
