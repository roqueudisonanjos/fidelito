import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation between the five primary company areas.
/// Keep this component reusable so the selected destination remains consistent.
class CompanyBottomNavigation extends StatelessWidget {
  const CompanyBottomNavigation({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const _paths = [
    '/company',
    '/company/manage',
    '/profile/editCompany',
    '/company/rewards',
    '/company/offers',
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(_paths[index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Gestão'),
        NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Dados'),
        NavigationDestination(icon: Icon(Icons.loyalty_outlined), selectedIcon: Icon(Icons.loyalty), label: 'Fidelidade'),
        NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Divulgação'),
      ],
    );
  }
}
