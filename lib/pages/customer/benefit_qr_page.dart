import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BenefitQrPage extends StatelessWidget {
  const BenefitQrPage({super.key, required this.benefit});

  final Map<String, dynamic> benefit;

  @override
  Widget build(BuildContext context) {
    final promotion = benefit['promotions'] as Map<String, dynamic>?;

    final company = benefit['companies'] as Map<String, dynamic>?;

    final id = benefit['id']?.toString() ?? '';

    final title = promotion?['title'] ?? 'Recompensa';

    final companyName = company?['name'] ?? 'Empresa';

    final points = benefit['points_spent'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Apresentar recompensa')),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              const Icon(Icons.card_giftcard, size: 60),

              const SizedBox(height: 20),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                companyName,
                style: const TextStyle(fontSize: 17, color: Colors.grey),
              ),

              const SizedBox(height: 8),

              Text(
                '$points pontos utilizados',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 32),

              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: QrImageView(
                    data: id,
                    version: QrVersions.auto,
                    size: 280,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Código para validação manual',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      id,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: id.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: id));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código copiado com sucesso!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar código'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Apresente este QR Code ou informe o código no estabelecimento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 8),

              const Text(
                'A empresa pode escanear o QR Code ou digitar o código para validar sua recompensa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
