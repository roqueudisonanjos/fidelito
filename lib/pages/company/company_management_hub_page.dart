import 'package:flutter/material.dart';

import '../../widgets/company/company_app_bar_actions.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/company/company_bottom_navigation.dart';

class CompanyManagementHubPage extends StatelessWidget {
  const CompanyManagementHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão'),
        actions: const [CompanyAppBarActions()],
      ),
      bottomNavigationBar: const CompanyBottomNavigation(selectedIndex: 1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              subtitle: const Text('Acompanhe indicadores do programa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/company/dashboard'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Meus clientes'),
              subtitle: const Text('Consulte participantes do programa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/company/customers'),
            ),
          ),
        ],
      ),
    );
  }
}
