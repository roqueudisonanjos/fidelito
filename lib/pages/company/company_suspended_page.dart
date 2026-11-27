import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/support_service.dart';
import '../../widgets/delete_account_section.dart';

class CompanySuspendedPage extends StatelessWidget {
  const CompanySuspendedPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresa suspensa'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 76,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 22),
                Text(
                  'Acesso suspenso',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'O programa de fidelidade da sua empresa está suspenso. '
                  'Enquanto a suspensão estiver ativa, sua empresa não poderá '
                  'utilizar os recursos do Plim, acessar o painel ou realizar '
                  'operações. Entre em contato com o suporte ApoloApps para obter ajuda.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => SupportService.openWhatsApp(context),
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Falar com o suporte'),
                  ),
                ),
                const SizedBox(height: 18),
                const DeleteAccountSection(isCompany: true),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
