import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/dashboard_service.dart';

class CompanyDashboardPage
    extends StatefulWidget {

  const CompanyDashboardPage({
    super.key,
  });

  @override
  State<CompanyDashboardPage>
      createState() =>
          _CompanyDashboardPageState();
}

class _CompanyDashboardPageState
    extends State<CompanyDashboardPage> {

  final DashboardService _service =
      DashboardService();

  bool _loading = true;

  String? _error;

  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  Future<void> _loadDashboard() async {

    setState(() {
      _loading = true;
      _error = null;
    });

    try {

      final data =
          await _service.getDashboard();

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Dashboard',
        ),
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh:
          _loadDashboard,

      child: ListView(
        padding:
            const EdgeInsets.all(20),

        children: [

          _buildHeader(),

          const SizedBox(
            height: 24,
          ),

          _buildMainStats(),

          const SizedBox(
            height: 28,
          ),

          _buildCustomersButton(),

          const SizedBox(
            height: 28,
          ),

          _buildBenefitsStats(),

          const SizedBox(
            height: 28,
          ),

          _buildPopularPromotions(),

          const SizedBox(
            height: 30,
          ),

        ],
      ),
    );
  }

  Widget _buildCustomersButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: () async {
          await context.push(
            '/company/customers',
          );
        },
        icon: const Icon(
          Icons.people_alt_rounded,
          size: 26,
        ),
        label: const Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Meus clientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              'Ver clientes, pontos e benefícios',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ],
        ),
        style: ElevatedButton.styleFrom(
          alignment:
              Alignment.centerLeft,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {

    final company =
        _data?['company']
            as Map<String, dynamic>?;

    final name =
        company?['name'] ??
        'Sua empresa';

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Text(
          'Dashboard',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          name.toString(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),

      ],
    );
  }

  Widget _buildMainStats() {

    final customers =
        _data?['customers'] ?? 0;

    final pointsEarned =
        _data?['points_earned'] ?? 0;

    final transactions =
        _data?['transactions'] ?? 0;

    final redemptions =
        _data?['redemptions'] ?? 0;

    return GridView.count(

      crossAxisCount: 2,

      crossAxisSpacing: 12,

      mainAxisSpacing: 12,

      shrinkWrap: true,

      physics:
          const NeverScrollableScrollPhysics(),

      childAspectRatio: 1.45,

      children: [

        _buildStatCard(
          icon: Icons.people_outline,
          title: 'Clientes',
          value:
              customers.toString(),
        ),

        _buildStatCard(
          icon: Icons.stars_outlined,
          title: 'Pontos distribuídos',
          value:
              pointsEarned.toString(),
        ),

        _buildStatCard(
          icon: Icons.swap_horiz,
          title: 'Transações',
          value:
              transactions.toString(),
        ),

        _buildStatCard(
          icon:
              Icons.card_giftcard_outlined,
          title: 'Resgates',
          value:
              redemptions.toString(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {

    return Card(

      elevation: 0,

      child: Padding(

        padding:
            const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Icon(
              icon,
              size: 28,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),

            const Spacer(),

            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsStats() {

    final available =
        _data?['available_benefits'] ??
            0;

    final used =
        _data?['used_benefits'] ?? 0;

    final cancelled =
        _data?['cancelled_benefits'] ??
            0;

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          'Benefícios',
          style: TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Card(

          child: Column(

            children: [

              _buildBenefitRow(
                icon:
                    Icons.pending_actions,
                title:
                    'Disponíveis',
                value:
                    available,
              ),

              const Divider(
                height: 1,
              ),

              _buildBenefitRow(
                icon:
                    Icons.check_circle_outline,
                title:
                    'Utilizados',
                value:
                    used,
              ),

              const Divider(
                height: 1,
              ),

              _buildBenefitRow(
                icon:
                    Icons.cancel_outlined,
                title:
                    'Cancelados',
                value:
                    cancelled,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required int value,
  }) {

    return ListTile(

      leading: Icon(icon),

      title: Text(title),

      trailing: Text(
        value.toString(),
        style: const TextStyle(
          fontWeight:
              FontWeight.bold,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _buildPopularPromotions() {

    final promotions =
        (_data?['popular_promotions']
                as List?) ??
            [];

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          'Benefícios mais resgatados',
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
                  EdgeInsets.all(18),

              child: Text(
                'Ainda não existem resgates.',
              ),
            ),
          )

        else

          ...promotions
              .take(5)
              .map(
                (promotion) {

                  final title =
                      promotion['title']
                          .toString();

                  final count =
                      promotion['redemptions']
                          as int;

                  return Card(

                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 8,
                    ),

                    child: ListTile(

                      leading:
                          const CircleAvatar(
                        child: Icon(
                          Icons
                              .card_giftcard,
                        ),
                      ),

                      title:
                          Text(title),

                      trailing:
                          Text(
                        '$count resgates',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final company =
                        _data?['company']
                            as Map<String, dynamic>?;

                    final companyId =
                        company?['id']?.toString();

                    if (companyId == null ||
                        companyId.isEmpty ||
                        companyId == 'null') {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Não foi possível identificar a empresa.',
                          ),
                        ),
                      );
                      return;
                    }

                    await context.push(
                      '/company/reports?companyId=$companyId',
                    );
                  },
                  icon: const Icon(
                    Icons.bar_chart,
                  ),
                  label: const Text(
                    'Relatórios de movimentações',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildError() {

    return Center(

      child: Padding(

        padding:
            const EdgeInsets.all(24),

        child: Column(

          mainAxisSize:
              MainAxisSize.min,

          children: [

            const Icon(
              Icons.error_outline,
              size: 50,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              _error!,
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 16,
            ),

            ElevatedButton(
              onPressed:
                  _loadDashboard,
              child:
                  const Text(
                'Tentar novamente',
              ),
            ),
          ],
        ),
      ),
    );
  }
}