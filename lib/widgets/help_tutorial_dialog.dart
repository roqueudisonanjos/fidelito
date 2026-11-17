import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class HelpTutorialDialog {
  static Future<void> show(BuildContext context, {required bool isCompany}) {
    final steps = isCompany
        ? const [
            _HelpStep(
              Icons.qr_code_2_rounded,
              'Receba clientes',
              'Gere QR Codes para registrar pontos ou localize um cliente para adicionar pontos manualmente.',
            ),
            _HelpStep(
              Icons.card_giftcard_rounded,
              'Crie recompensas',
              'Cadastre descontos e brindes, definindo quantos pontos são necessários para o resgate.',
            ),
            _HelpStep(
              Icons.qr_code_scanner_rounded,
              'Valide resgates',
              'Use o leitor de recompensas para conferir e registrar a utilização pelo cliente.',
            ),
            _HelpStep(
              Icons.insights_rounded,
              'Acompanhe resultados',
              'Consulte o dashboard e os relatórios para acompanhar clientes, pontos e recompensas.',
            ),
            _HelpStep(
              Icons.person_outline_rounded,
              'Mantenha seus dados atualizados',
              'Acesse Dados cadastrais para editar as informações da empresa e atualizar a senha da conta.',
            ),
          ]
        : const [
            _HelpStep(
              Icons.explore_outlined,
              'Encontre empresas',
              'Explore empresas disponíveis e conheça os programas de fidelidade.',
            ),
            _HelpStep(
              Icons.loyalty_rounded,
              'Participe de programas',
              'Entre nos programas que desejar. Cada empresa tem seu próprio saldo de pontos.',
            ),
            _HelpStep(
              Icons.qr_code_scanner_rounded,
              'Acumule pontos',
              'Na loja, escaneie o QR Code apresentado pela empresa para receber pontos.',
            ),
            _HelpStep(
              Icons.card_giftcard_rounded,
              'Resgate recompensas',
              'Use seus pontos para resgatar descontos e brindes. Suas recompensas resgatadas ficam disponíveis em Minhas recompensas.',
            ),
            _HelpStep(
              Icons.person_outline_rounded,
              'Gerencie sua conta',
              'Em Dados cadastrais, atualize suas informações e sua senha. Você também pode sair de um programa quando quiser.',
            ),
          ];

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCompany ? 'Como usar o Fidelito' : 'Como funciona o Fidelito',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  _HelpStepTile(number: index + 1, step: steps[index]),
                  if (index != steps.length - 1) const Divider(height: 18),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

class _HelpStep {
  const _HelpStep(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

class _HelpStepTile extends StatelessWidget {
  const _HelpStepTile({required this.number, required this.step});
  final int number;
  final _HelpStep step;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 21,
        backgroundColor: AppColors.primaryLight,
        child: Icon(step.icon, color: AppColors.primary, size: 21),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${number.toString()}. ${step.title}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              step.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );
}
