import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/loyalty_program_service.dart';
import '../../services/company_offer_service.dart';
import '../../services/share_service.dart';

class CompanyDetailsPage extends StatefulWidget {
  const CompanyDetailsPage({super.key, this.company = const {}, this.companyId, this.offerId});

  final Map<String, dynamic> company;
  final String? companyId;
  final String? offerId;

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  final _service = LoyaltyProgramService();
  final _offerService = CompanyOfferService();
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _rewards = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = {};

  String get _companyId => widget.company['id']?.toString() ?? widget.companyId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _error = 'Não foi possível identificar esta empresa.';
        _loading = false;
      });
      return;
    }

    try {
      final details = await _service.getCompanyDetails(_companyId);
      List<Map<String, dynamic>> offers = [];
      List<Map<String, dynamic>> rewards = [];
      bool joined = widget.company['joined'] == true;
      try {
        offers = await _offerService.getPublicOffers(companyId: _companyId);
        if (widget.offerId != null) {
          offers.sort((a, b) {
            final aTarget = a['id']?.toString() == widget.offerId ? 1 : 0;
            final bTarget = b['id']?.toString() == widget.offerId ? 1 : 0;
            return bTarget.compareTo(aTarget);
          });
        }
      } catch (_) {}
      try {
        rewards = await _service.getCompanyPromotions(_companyId);
        rewards = rewards.where((reward) => ((reward['points_required'] as num?)?.toInt() ?? 0) > 0).toList();
      } catch (_) {}
      // Shared deep links do not carry navigation extras, so resolve membership.
      if (!joined) {
        try {
          final myPrograms = await _service.getMyPrograms();
          joined = myPrograms.any((program) =>
              program['company_id']?.toString() == _companyId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _company = {...widget.company, ...details, 'joined': joined};
        _offers = offers;
        _rewards = rewards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String get _phoneDigits =>
      (_company['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _openWhatsApp() async {
    var number = _phoneDigits;
    if (number.isEmpty) return;
    if (!number.startsWith('55')) number = '55$number';

    final uri = Uri.parse('https://wa.me/$number');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  String _socialUsername(String key) =>
      (_company[key] ?? '').toString().trim().replaceFirst(RegExp(r'^@+'), '');

  Future<void> _openSocial(String platform, String username) async {
    if (username.isEmpty) return;
    final uri = Uri.parse(platform == 'instagram'
        ? 'https://www.instagram.com/$username/'
        : 'https://www.tiktok.com/@$username');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o $platform.')),
      );
    }
  }


  String get _location {
    final city = (_company['city'] ?? '').toString().trim();
    final state = (_company['state'] ?? '').toString().trim();
    return [city, state].where((part) => part.isNotEmpty).join(' - ');
  }

  String _formatOfferDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'data não informada';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _rewardSubtitle(Map<String, dynamic> reward) {
    final points = (reward['points_required'] as num?)?.toInt() ?? 1;
    final description = (reward['description']?.toString() ?? '').trim();
    final discount = reward['discount_percentage'];
    final gift = (reward['gift_description']?.toString() ?? '').trim();
    final benefit = reward['type'] == 'discount' && discount != null
        ? '$discount% de desconto'
        : gift.isNotEmpty ? gift : 'Benefício especial';
    return [benefit, '$points pontos', if (description.isNotEmpty) description].join('\n');
  }

  Widget _buildRewardsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      Text('Recompensas de fidelidade', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ..._rewards.map((reward) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: (reward['image_url']?.toString() ?? '').isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(reward['image_url'].toString(), width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard_outlined)))
              : const Icon(Icons.card_giftcard_outlined, size: 36),
          title: Text(reward['title']?.toString() ?? 'Recompensa'),
          subtitle: Text(_rewardSubtitle(reward)),
          isThreeLine: (reward['description']?.toString() ?? '').trim().isNotEmpty,
        ),
      )),
    ]);
  }


  @override
  Widget build(BuildContext context) {
    final name = (_company['name'] ?? 'Empresa').toString();
    final description = (_company['description'] ?? '').toString().trim();
    final address = (_company['address'] ?? '').toString().trim();
    final phone = (_company['phone'] ?? '').toString().trim();
    final logoUrl = (_company['logo_url'] ?? '').toString().trim();
    final instagram = _socialUsername('instagram_username');
    final tiktok = _socialUsername('tiktok_username');
    final joined = _company['joined'] == true;
    final fullAddress = [
      if (address.isNotEmpty) address,
      if (_location.isNotEmpty) _location,
    ].join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre a empresa'),
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          backgroundImage: logoUrl.isNotEmpty
                              ? NetworkImage(logoUrl)
                              : null,
                          child: logoUrl.isEmpty
                              ? const Icon(Icons.storefront_outlined, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => ShareService.shareCompanyClub(
                            companyName: name,
                            companyLogoUrl: logoUrl,
                            companyId: _companyId,
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar empresa'),
                        ),
                        if (_location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 17),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _location,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if ((_company['category']?.toString() ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.center, child: Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(_company['category'].toString()))),
                ],
                if (_offers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Ofertas disponíveis', style: Theme.of(context).textTheme.titleLarge),
                  if (widget.offerId != null) ...[
                    const SizedBox(height: 6),
                    Text(_offers.any((offer) => offer['id']?.toString() == widget.offerId) ? 'Oferta compartilhada em destaque' : 'Esta oferta não está mais ativa ou disponível.', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 8),
                  ..._offers.map((offer) => Card(
                    clipBehavior: Clip.antiAlias,
                    shape: offer['id']?.toString() == widget.offerId ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)) : null,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((offer['image_url']?.toString() ?? '').isNotEmpty)
                        Image.network(offer['image_url'].toString(), height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(offer['title']?.toString() ?? 'Oferta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        if ((offer['description']?.toString() ?? '').trim().isNotEmpty) ...[const SizedBox(height: 6), Text(offer['description'].toString())],
                        const SizedBox(height: 8),
                        Text('Válida de ${_formatOfferDate(offer['starts_at'])} até ${_formatOfferDate(offer['ends_at'])}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(onPressed: () => ShareService.shareOffer(companyName: name, title: offer['title']?.toString() ?? 'Oferta', description: offer['description']?.toString(), companyLogoUrl: logoUrl, companyId: _companyId, offerId: offer['id']?.toString()), icon: const Icon(Icons.share_outlined), label: const Text('Compartilhar oferta')),
                      ])),
                    ]),
                  )),
                ],
                if (_offers.isEmpty && widget.offerId != null) ...[
                  const SizedBox(height: 12),
                  Text('Esta oferta não está mais ativa ou disponível.', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                ],
                if (_rewards.isNotEmpty) _buildRewardsSection(),
                const SizedBox(height: 18),
                Text(
                  'Sobre a empresa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      description.isNotEmpty
                          ? description
                          : 'Esta empresa ainda não adicionou uma descrição.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Contato e endereço',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('WhatsApp'),
                        subtitle: Text(
                          phone.isNotEmpty ? phone : 'Não informado',
                        ),
                        trailing: phone.isNotEmpty
                            ? const Icon(Icons.open_in_new, size: 18)
                            : null,
                        onTap: phone.isNotEmpty ? _openWhatsApp : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Endereço'),
                        subtitle: Text(
                          fullAddress.isNotEmpty
                              ? fullAddress
                              : 'Não informado',
                        ),
                        isThreeLine: address.isNotEmpty && _location.isNotEmpty,
                      ),
                    ],
                  ),
                ),
                if (instagram.isNotEmpty || tiktok.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Redes sociais',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        if (instagram.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.camera_alt_outlined),
                            title: const Text('Instagram'),
                            subtitle: Text('@$instagram'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _openSocial('instagram', instagram),
                          ),
                        if (instagram.isNotEmpty && tiktok.isNotEmpty)
                          const Divider(height: 1),
                        if (tiktok.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.music_note_outlined),
                            title: const Text('TikTok'),
                            subtitle: Text('@$tiktok'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _openSocial('tiktok', tiktok),
                          ),
                      ],
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Conversar pelo WhatsApp'),
                  ),
                ],
                const SizedBox(height: 10),
                if (joined)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final left = await context.push<bool>(
                        '/customer/loyalty-program',
                        extra: _company,
                      );
                      if (!context.mounted) return;
                      if (left == true) context.pop(true);
                    },
                    icon: const Icon(Icons.loyalty_outlined),
                    label: const Text('Ver minha fidelidade'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _service.joinProgram(_companyId);
                        if (!mounted) return;
                        setState(() => _company['joined'] = true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Agora você participa da fidelidade de $name!')),
                        );
                        await context.push('/customer/loyalty-program', extra: {..._company, 'joined': true});
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Participar da fidelidade'),
                  ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
