import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/company_offer_service.dart';
import '../../services/share_service.dart';

class SharedOfferDetailsPage extends StatefulWidget {
  const SharedOfferDetailsPage({super.key, required this.offerId});
  final String offerId;

  @override
  State<SharedOfferDetailsPage> createState() => _SharedOfferDetailsPageState();
}


class _SharedOfferDetailsPageState extends State<SharedOfferDetailsPage> {
  final _service = CompanyOfferService();
  Map<String, dynamic>? _offer;
  bool _loading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<void> _load() async {
    try {
      final offers = await _service.getPublicOffers();
      final matches = offers.where((item) => item['id']?.toString() == widget.offerId);
      if (!mounted) return;
      setState(() {
        _offer = matches.isEmpty ? null : matches.first;
        _loading = false;
        if (_offer == null) _error = 'Esta oferta não está mais ativa ou disponível.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os detalhes da oferta.';
        _loading = false;
      });
    }
  }


  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }


  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final company = offer == null ? <String, dynamic>{} : Map<String, dynamic>.from(offer['companies'] ?? {});
    final companyName = company['name']?.toString() ?? 'Empresa';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da oferta'),
        actions: [
          IconButton(
            tooltip: 'Ir para Home do Fidelito',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((offer?['image_url']?.toString() ?? '').trim().isNotEmpty)
                      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(offer!['image_url'].toString(), width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
                    const SizedBox(height: 16),
                    Text(offer?['title']?.toString() ?? 'Oferta', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if ((offer?['description']?.toString() ?? '').trim().isNotEmpty)
                      Text(offer!['description'].toString(), style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 12),
                    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Validade da oferta', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('De ${_formatDate(offer?['starts_at'])} até ${_formatDate(offer?['ends_at'])}'),
                    ]))),
                    const SizedBox(height: 16),
                    Card(child: ListTile(
                      leading: (company['logo_url']?.toString() ?? '').trim().isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(company['logo_url'].toString()))
                          : const CircleAvatar(child: Icon(Icons.store_outlined)),
                      title: Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text([company['city'], company['state']].where((v) => v != null && v.toString().trim().isNotEmpty).join(' - ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/empresa/${company['id']}'),
                    )),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      icon: const Icon(Icons.store_outlined),
                      label: const Text('Ver empresa'),
                      onPressed: () => context.push('/empresa/${company['id']}'),
                    )),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar oferta'),
                      onPressed: () => ShareService.shareOffer(
                        companyName: companyName,
                        title: offer?['title']?.toString() ?? 'Oferta',
                        description: offer?['description']?.toString(),
                        companyLogoUrl: company['logo_url']?.toString(),
                        companyId: company['id']?.toString(),
                        offerId: offer?['id']?.toString(),
                      ),
                    )),
                  ]),
                ),
    );
  }
}
