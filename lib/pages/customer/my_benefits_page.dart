import 'package:flutter/material.dart';

import '../../services/benefit_service.dart';
import '../../widgets/company_rating_display.dart';
import 'package:go_router/go_router.dart';

class MyBenefitsPage extends StatefulWidget {
  const MyBenefitsPage({super.key});

  @override
  State<MyBenefitsPage> createState() => _MyBenefitsPageState();
}

class _MyBenefitsPageState extends State<MyBenefitsPage> {
  final BenefitService _service = BenefitService();

  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> _benefits = [];

  @override
  void initState() {
    super.initState();

    _loadBenefits();
  }

  Future<void> _loadBenefits() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final benefits = await _service.getMyBenefits();

      if (!mounted) return;

      setState(() {
        _benefits = benefits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas recompensas')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: _benefits.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _benefits.length,
              itemBuilder: (context, index) {
                return _buildBenefitCard(_benefits[index]);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: ListView(
        children: const [
          SizedBox(height: 180),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Você ainda não possui recompensas.',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Resgate uma promoção para vê-la aqui.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: ListView(
        children: [
          const SizedBox(height: 180),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 50),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBenefits,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(Map<String, dynamic> benefit) {
    final promotion = benefit['promotions'] as Map<String, dynamic>?;

    final company = benefit['companies'] as Map<String, dynamic>?;

    final title = promotion?['title'] ?? 'Recompensa';

    final companyName = company?['name'] ?? 'Empresa';

    final description = promotion?['description'];

    final endsAt = _parseDate(promotion?['ends_at']);

    final type = promotion?['type'];

    final discount = promotion?['discount_percentage'];

    final gift = promotion?['gift_description'];

    final pointsSpent = benefit['points_spent'] ?? 0;

    final status = benefit['status'] ?? 'available';

    final redeemedAt = _parseDate(benefit['redeemed_at']);

    final usedAt = _parseDate(benefit['used_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),

      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        onTap: status == 'available'
            ? () {
                context.push('/customer/benefit-qr', extra: benefit);
              }
            : null,

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((promotion?['image_url'] ?? '').toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    promotion!['image_url'].toString(),
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage: (company?['logo_url'] ?? '').toString().isNotEmpty
                                    ? NetworkImage(company!['logo_url'].toString()) : null,
                                child: (company?['logo_url'] ?? '').toString().isNotEmpty
                                    ? null : const Icon(Icons.storefront_outlined, size: 14),
                              ),
                              if (company?['id'] != null)
                                CompanyRatingLookup(companyId: company!['id'].toString(), compact: true),
                            ]),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                companyName,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusChip(status),

                      if (status == 'available') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (type == 'discount' && discount != null)
                Text(
                  '${discount.toString()}% de desconto',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              if (type == 'gift' && gift != null)
                Text(
                  gift.toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description.toString(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],

              const Divider(height: 28),

              Row(
                children: [
                  const Icon(Icons.stars_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('$pointsSpent pontos utilizados'),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Resgatado em ${_formatDate(redeemedAt)}'),
                ],
              ),

              if (usedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Text('Usado em ${_formatDate(usedAt)}'),
                  ],
                ),
              ],

              if (status == 'available') ...[
                const SizedBox(height: 16),

                _buildAvailableMessage(),

                const SizedBox(height: 14),
              ],

              if (endsAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Expira em ${_formatDateOnly(endsAt)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateOnly(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    return '$day/$month/$year';
  }

  Widget _buildStatusChip(String status) {
    String text;

    Color color;

    IconData icon;

    switch (status) {
      case 'used':
        text = 'Usado';
        color = Colors.blue;
        icon = Icons.check_circle;
        break;

      case 'cancelled':
        text = 'Cancelado';
        color = Colors.red;
        icon = Icons.cancel;
        break;

      case 'available':
      default:
        text = 'Disponível';
        color = Colors.green;
        icon = Icons.card_giftcard;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Apresente esta recompensa no estabelecimento para utilizá-la.',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }
}
