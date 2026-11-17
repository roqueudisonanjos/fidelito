import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BenefitDetailPage extends StatelessWidget {
  const BenefitDetailPage({super.key, required this.benefit});

  final Map<String, dynamic> benefit;

  @override
  Widget build(BuildContext context) {
    final promotion = benefit['promotions'] as Map<String, dynamic>?;

    final company = benefit['companies'] as Map<String, dynamic>?;

    final title = promotion?['title'] ?? 'Recompensa';

    final companyName = company?['name'] ?? 'Empresa';

    final description = promotion?['description'];

    final pointsSpent = benefit['points_spent'] ?? 0;

    final status = benefit['status'] ?? 'available';

    final redemptionId = benefit['id'];

    final type = promotion?['type'];

    final discount = promotion?['discount_percentage'];

    final gift = promotion?['gift_description'];

    String rewardText = '';

    if (type == 'discount' && discount != null) {
      rewardText = '${discount.toString()}% de desconto';
    }

    if (type == 'gift' && gift != null) {
      rewardText = gift.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meu recompensa')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            // Ícone
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.card_giftcard,
                size: 42,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 20),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              companyName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),

            if (rewardText.isNotEmpty) ...[
              const SizedBox(height: 20),

              Text(
                rewardText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],

            if (description != null) ...[
              const SizedBox(height: 12),

              Text(
                description.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],

            const SizedBox(height: 20),

            Text(
              '$pointsSpent pontos utilizados',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 32),

            // =====================================
            // BENEFÍCIO DISPONÍVEL
            // =====================================
            if (status == 'available') ...[
              const Text(
                'Apresente este QR Code no estabelecimento',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      color: Colors.black.withValues(alpha: .08),
                    ),
                  ],
                ),
                child: QrImageView(data: redemptionId.toString(), size: 260),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Recompensa disponível. '
                        'A empresa deverá escanear '
                        'este código para confirmar '
                        'a utilização.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // =====================================
            // BENEFÍCIO USADO
            // =====================================
            if (status == 'used')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.blue),

                    SizedBox(height: 12),

                    Text(
                      'Recompensa já utilizada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Esta recompensa não pode ser utilizado novamente.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // =====================================
            // BENEFÍCIO CANCELADO
            // =====================================
            if (status == 'cancelled')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.cancel, size: 48, color: Colors.red),

                    SizedBox(height: 12),

                    Text(
                      'Recompensa cancelada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
