import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/promotion.dart';
import '../../widgets/company_rating_display.dart';

class AllPromotionsPage extends StatelessWidget {
  const AllPromotionsPage({super.key, required this.promotions});

  final List<Promotion> promotions;

  String _rewardText(Promotion promotion) {
    if (promotion.type == 'discount' && promotion.discountPercentage != null) {
      return '${promotion.discountPercentage!.toStringAsFixed(0)}% de desconto';
    }
    return promotion.giftDescription?.trim().isNotEmpty == true
        ? promotion.giftDescription!
        : 'Brinde';
  }

  @override
  Widget build(BuildContext context) {
    final visiblePromotions = promotions.where((promotion) => promotion.pointsRequired > 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Todas as recompensas')),
      body: visiblePromotions.isEmpty
          ? const Center(child: Text('Nenhuma recompensa disponível.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visiblePromotions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final promotion = visiblePromotions[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(
                      '/customer/company-details',
                      extra: <String, dynamic>{
                        'id': promotion.companyId,
                        'name': promotion.companyName,
                        'joined': true,
                      },
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((promotion.imageUrl ?? '').isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                promotion.imageUrl!,
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          if ((promotion.imageUrl ?? '').isNotEmpty)
                            const SizedBox(height: 12),
                          Row(
                            children: [
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundImage: (promotion.companyLogoUrl ?? '').isNotEmpty ? NetworkImage(promotion.companyLogoUrl!) : null,
                                  child: (promotion.companyLogoUrl ?? '').isNotEmpty ? null : const Icon(Icons.storefront, size: 18),
                                ),
                                CompanyRatingLookup(companyId: promotion.companyId, compact: true),
                              ]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  promotion.companyName ?? 'Empresa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            promotion.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _rewardText(promotion),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if ((promotion.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(promotion.description!),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.stars_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 5),
                              Text(
                                '${promotion.pointsRequired} pontos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
