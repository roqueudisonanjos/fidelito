import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/loyalty_transaction.dart';
import '../../models/promotion.dart';
import '../../services/auth_service.dart';
import '../../services/customer_service.dart';
import '../../services/promotion_service.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
  });

  @override
  State<CustomerHomePage> createState() =>
      _CustomerHomePageState();
}

class _CustomerHomePageState
    extends State<CustomerHomePage> {

  final PromotionService promotionService =
      PromotionService();

  final CustomerService customerService =
      CustomerService();

  final AuthService authService =
      AuthService();

  bool loading = true;

  String customerName = '';

  Map<String, int> companyPoints = {};

  List<Promotion> promotions = [];

  List<LoyaltyTransaction> transactions =
      [];

  String? error;

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> redeemPromotion(
    Promotion promotion,
  ) async {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    if (availablePoints < promotion.pointsRequired) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Você não possui pontos suficientes.',
          ),
        ),
      );

      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Resgatar benefício?',
          ),
          content: Text(
            'Você vai utilizar '
            '${promotion.pointsRequired} pontos '
            'para resgatar:\n\n'
            '${promotion.title}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Resgatar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result =
          await promotionService
              .redeemPromotion(
        promotion.id,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Benefício resgatado! 🎉',
            ),
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
                  Navigator.pop(
                    context,
                  );
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results =
          await Future.wait([
        customerService.getProfile(),
        customerService.getPointsByCompany(),
        customerService.getPromotions(),
        customerService.getTransactions(),
      ]);

      final profile =
          results[0]
              as Map<String, dynamic>?;

      final loadedCompanyPoints =
          results[1] as Map<String, int>;

      final loadedPromotions =
          results[2] as List<Promotion>;

      final loadedTransactions =
          results[3] as List<LoyaltyTransaction>;

      if (!mounted) return;

      setState(() {
        customerName =
            profile?['full_name'] ??
            'Cliente';

        companyPoints = loadedCompanyPoints;

        promotions =
            loadedPromotions;

        transactions =
            loadedTransactions;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error =
            'Não foi possível carregar seus dados.';

        loading = false;
      });
    }
  }

  Future<void> logout() async {
    await authService.logout();

    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fidelito',
        ),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon:
                const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Escanear QR Code',
        onPressed: _openScanner,
        child: const Icon(Icons.qr_code_scanner, size: 30),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(
          height:
              MediaQuery.of(context)
                  .size
                  .height *
                  .7,
        ),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(error!),
              const SizedBox(
                height: 16,
              ),
              ElevatedButton(
                onPressed: loadData,
                child: const Text(
                  'Tentar novamente',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      padding:
          const EdgeInsets.all(20),
      children: [
        Text(
          'Olá, $customerName!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Continue acumulando pontos e aproveite seus benefícios.',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 28),

        _buildPromotions(),

        const SizedBox(height: 32),

        _buildTransactions(),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.push(
                '/customer/transactions',
              );
            },
            icon: const Icon(
              Icons.history,
            ),
            label: const Text(
              'Ver histórico completo',
            ),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Explorar empresas',
              onPressed: () => context.push('/customer/explore'),
              icon: const Icon(Icons.explore_outlined),
            ),
            IconButton(
              tooltip: 'Minhas fidelidades',
              onPressed: () => context.push('/customer/my-loyalties'),
              icon: const Icon(Icons.loyalty_outlined),
            ),
            const SizedBox(width: 76),
            IconButton(
              tooltip: 'Meus benefícios',
              onPressed: () => context.push('/customer/my-benefits'),
              icon: const Icon(Icons.card_giftcard_outlined),
            ),
            IconButton(
              tooltip: 'Dados cadastrais',
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    final result = await context.push<bool>('/customer/scan');
    if (!mounted) return;
    if (result == true) await loadData();
  }

  Future<void> _openProfile() async {
    final result = await context.push<bool>('/profile/edit');
    if (!mounted) return;
    if (result == true) await loadData();
  }

  Widget _buildPromotions() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Benefícios disponíveis',
          style: TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        if (promotions.isEmpty)
          const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Text(
                'Nenhum benefício disponível no momento.',
              ),
            ),
          )
        else
          ...promotions.map(
            _buildPromotionCard,
          ),
      ],
    );
  }

  Widget _buildPromotionCard(
    Promotion promotion,
  ) {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    final canRedeem = availablePoints >= promotion.pointsRequired;

    String rewardText;

    if (promotion.type ==
            'discount' &&
        promotion.discountPercentage !=
            null) {
      rewardText =
          '${promotion.discountPercentage!.toStringAsFixed(0)}% de desconto';
    } else {
      rewardText =
          promotion.giftDescription ??
          'Brinde';
    }

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    promotion.title,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    color: canRedeem
                        ? Colors.green
                            .withValues(alpha: .12)
                        : Colors.grey
                            .withValues(alpha: .12),
                  ),
                  child: Text(
                    '${promotion.pointsRequired} pts',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: canRedeem
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              rewardText,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
                color:
                    Theme.of(context)
                        .colorScheme
                        .primary,
              ),
            ),

            if (promotion.description !=
                null) ...[
              const SizedBox(
                height: 6,
              ),
              Text(
                promotion.description!,
                style:
                    const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],

            // VALIDADE
            if (promotion.endsAt !=
                null) ...[
              const SizedBox(
                height: 12,
              ),

              _buildValidityInfo(
                promotion.endsAt!,
              ),
            ],

            const SizedBox(
              height: 12,
            ),

            Text(
              canRedeem
                  ? 'Você já pode resgatar este benefício.'
                  : 'Faltam ${promotion.pointsRequired - availablePoints} pontos nesta empresa.',
              style: TextStyle(
                color: canRedeem
                    ? Colors.green
                    : Colors.grey,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton(
                onPressed: canRedeem
                    ? () =>
                        redeemPromotion(
                          promotion,
                        )
                    : null,
                child: Text(
                  canRedeem
                      ? 'Resgatar benefício'
                      : 'Pontos insuficientes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidityInfo(
    DateTime endsAt,
  ) {
    final local =
        endsAt.toLocal();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Colors.orange.withValues(
          alpha: .08,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_outlined,
            size: 20,
            color: Colors.orange,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Text(
              'Válido até ${_formatDateOnly(local)}',
              style:
                  const TextStyle(
                color: Colors.orange,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Histórico de pontos',
          style: TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Text(
                'Você ainda não possui movimentações.',
              ),
            ),
          )
        else
          ...transactions.map(
            _buildTransaction,
          ),
      ],
    );
  }

  Widget _buildTransaction(
    LoyaltyTransaction transaction,
  ) {
    final isEarn =
        transaction.points > 0;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isEarn
                ? Icons.add
                : Icons.remove,
          ),
        ),
        title: Text(
          transaction.description ??
              'Movimentação de pontos',
        ),
        subtitle: Text(
          _formatDate(
            transaction.createdAt,
          ),
        ),
        trailing: Text(
          '${isEarn ? '+' : ''}${transaction.points}',
          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
            color: isEarn
                ? Colors.green
                : Colors.red,
          ),
        ),
      ),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final day =
        local.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final year =
        local.year.toString();

    final hour =
        local.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/$year às $hour:$minute';
  }

  String _formatDateOnly(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final year =
        date.year.toString();

    return '$day/$month/$year';
  }
}