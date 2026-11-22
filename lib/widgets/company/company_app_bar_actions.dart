import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/support_service.dart';
import '../help_tutorial_dialog.dart';

/// Consistent help/support/logout actions across the company area.
class CompanyAppBarActions extends StatelessWidget {
  const CompanyAppBarActions({super.key, this.onRefresh, this.refreshEnabled = true});

  final VoidCallback? onRefresh;
  final bool refreshEnabled;

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().logout();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
        if (onRefresh != null)
          IconButton(
            tooltip: 'Atualizar',
            onPressed: refreshEnabled ? onRefresh : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        IconButton(
          tooltip: 'Suporte ApoloApps',
          onPressed: () => SupportService.openWhatsApp(context),
          icon: const Icon(Icons.support_agent_rounded),
        ),
        IconButton(
          tooltip: 'Ajuda',
          onPressed: () => HelpTutorialDialog.show(context, isCompany: true),
          icon: const Icon(Icons.help_outline_rounded),
        ),
        IconButton(
          tooltip: 'Sair',
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded),
        ),
        ],
      );
}
