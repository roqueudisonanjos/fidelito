import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/loyalty_transaction.dart';
import '../../models/promotion.dart';
import '../../services/auth_service.dart';
import '../../services/customer_service.dart';
import '../../services/promotion_service.dart';
import '../../services/support_service.dart';
import '../../services/share_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/help_tutorial_dialog.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final PromotionService promotionService = PromotionService();

  final CustomerService customerService = CustomerService();

  final AuthService authService = AuthService();

  final NotificationService _notificationService = NotificationService();
  late Future<int> _unreadNotificationsFuture;

  bool loading = true;

  String customerName = '';
  String? customerAvatarUrl;

  Map<String, int> companyPoints = {};

  List<Promotion> promotions = [];

  Set<String> redeemedPromotionIds = {};

  List<LoyaltyTransaction> transactions = [];

  String? error;

  @override
  void initState() {
    super.initState();

    _unreadNotificationsFuture = _notificationService.getUnreadCount();
    loadData();
  }

  Future<void> redeemPromotion(Promotion promotion) async {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    if (availablePoints < promotion.pointsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não possui pontos suficientes.')),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resgatar recompensa?'),
          content: Text(
            promotion.pointsRequired == 0
                ? 'Você vai resgatar gratuitamente:\n\n${promotion.title}'
                : 'Você vai utilizar ${promotion.pointsRequired} pontos para resgatar:\n\n${promotion.title}',
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
      final result = await promotionService.redeemPromotion(promotion.id);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Recompensa resgatada! 🎉'),
            content: Text(
              '${result['title']}\n\n'
              'Pontos utilizados: ${result['points_spent']}\n\n'
              'Novo saldo: ${result['new_balance']} pontos.',
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

      await loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        customerService.getProfile(),
        customerService.getPointsByCompany(),
        customerService.getPromotions(),
        customerService.getTransactions(),
        promotionService.getMyRedeemedPromotionIds(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;

      final loadedCompanyPoints = results[1] as Map<String, int>;

      final loadedPromotions = results[2] as List<Promotion>;

      final loadedTransactions = results[3] as List<LoyaltyTransaction>;
      final loadedRedeemedPromotionIds = results[4] as Set<String>;

      if (!mounted) return;

      setState(() {
        customerName = profile?['full_name'] ?? 'Cliente';
        customerAvatarUrl = profile?['avatar_url']?.toString();

        companyPoints = loadedCompanyPoints;

        promotions = loadedPromotions;

        transactions = loadedTransactions;

        redeemedPromotionIds = loadedRedeemedPromotionIds;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Não foi possível carregar seus dados.';

        loading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await context.push('/customer/notifications');
    if (!mounted) return;
    setState(() {
      _unreadNotificationsFuture = _notificationService.getUnreadCount();
    });
  }

  Future<void> logout() async {
    await authService.logout();

    if (!mounted) return;

    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fidelito'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar Fidelito',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => ShareService.shareApp(),
          ),
          FutureBuilder<int>(
            future: _unreadNotificationsFuture,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notificações',
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: _openNotifications,
              );
            },
          ),
          IconButton(
            tooltip: 'Suporte ApoloApps',
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () => SupportService.openWhatsApp(context),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loadData,
          ),
          IconButton(
            tooltip: 'Ajuda',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => HelpTutorialDialog.show(context, isCompany: false),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Escanear QR Code',
        onPressed: _openScanner,
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * .7),
        Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadData,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white.withValues(alpha: .18),
                backgroundImage:
                    customerAvatarUrl == null || customerAvatarUrl!.isEmpty
                    ? null
                    : NetworkImage(customerAvatarUrl!),
                child: customerAvatarUrl == null || customerAvatarUrl!.isEmpty
                    ? const Icon(Icons.waving_hand_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                'Olá, $customerName!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Continue acumulando pontos e aproveite suas recompensas.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .88),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
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
              context.push('/customer/transactions');
            },
            icon: const Icon(Icons.history),
            label: const Text('Ver histórico completo'),
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
              tooltip: 'Minhas recompensas',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recompensas disponíveis',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        if (promotions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhuma recompensa disponível no momento.'),
            ),
          )
        else
          ...promotions.map(_buildPromotionCard),
      ],
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    final alreadyRedeemedFree =
        promotion.pointsRequired == 0 &&
        redeemedPromotionIds.contains(promotion.id);
    final canRedeem =
        !alreadyRedeemedFree && availablePoints >= promotion.pointsRequired;

    String rewardText;

    if (promotion.type == 'discount' && promotion.discountPercentage != null) {
      rewardText =
          '${promotion.discountPercentage!.toStringAsFixed(0)}% de desconto';
    } else {
      rewardText = promotion.giftDescription ?? 'Brinde';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final left = await context.push<bool>(
          '/customer/company-details',
          extra: <String, dynamic>{
            'id': promotion.companyId,
            'name': promotion.companyName,
            'joined': true,
          },
        );
        if (left == true && mounted) await loadData();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (promotion.imageUrl != null &&
                  promotion.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    promotion.imageUrl!,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if ((promotion.companyName ?? '').trim().isNotEmpty) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          (promotion.companyLogoUrl ?? '').isNotEmpty
                          ? NetworkImage(promotion.companyLogoUrl!)
                          : null,
                      child: (promotion.companyLogoUrl ?? '').isNotEmpty
                          ? null
                          : const Icon(Icons.storefront_outlined, size: 14),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        promotion.companyName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      promotion.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Compartilhar recompensa',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ShareService.sharePromotion(
                      companyName: promotion.companyName ?? 'Empresa',
                      title: promotion.title,
                      type: promotion.type,
                      discountPercentage: promotion.discountPercentage?.toStringAsFixed(0),
                      giftDescription: promotion.giftDescription,
                      description: promotion.description,
                      companyLogoUrl: promotion.companyLogoUrl,
                    ),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: canRedeem
                          ? Colors.green.withValues(alpha: .12)
                          : Colors.grey.withValues(alpha: .12),
                    ),
                    child: Text(
                      promotion.pointsRequired == 0 ? 'Grátis' : '${promotion.pointsRequired} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canRedeem ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                rewardText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              if (promotion.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  promotion.description!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],

              // VALIDADE
              if (promotion.endsAt != null) ...[
                const SizedBox(height: 12),

                _buildValidityInfo(promotion.endsAt!),
              ],

              const SizedBox(height: 12),

              Text(
                alreadyRedeemedFree
                    ? 'Você já resgatou esta recompensa gratuita.'
                    : canRedeem
                    ? 'Você já pode resgatar esta recompensa.'
                    : 'Faltam ${promotion.pointsRequired - availablePoints} pontos nesta empresa.',
                style: TextStyle(
                  color: alreadyRedeemedFree
                      ? Colors.grey
                      : canRedeem
                      ? Colors.green
                      : Colors.grey,
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canRedeem
                      ? () => redeemPromotion(promotion)
                      : null,
                  style: ElevatedButton.styleFrom(
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
                        : canRedeem
                        ? 'Resgatar recompensa'
                        : 'Pontos insuficientes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidityInfo(DateTime endsAt) {
    final local = endsAt.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_outlined, size: 20, color: Colors.orange),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Válido até ${_formatDateOnly(local)}',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Histórico de pontos',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Você ainda não possui movimentações.'),
            ),
          )
        else
          ...transactions.map(_buildTransaction),
      ],
    );
  }

  Widget _buildTransaction(LoyaltyTransaction transaction) {
    final isEarn = transaction.points > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(isEarn ? Icons.add : Icons.remove)),
        title: Text(transaction.description ?? 'Movimentação de pontos'),
        subtitle: Text(_formatDate(transaction.createdAt)),
        trailing: Text(
          '${isEarn ? '+' : ''}${transaction.points}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isEarn ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$day/$month/$year';
  }
}
