import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/location_service.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/profile_service.dart';
import '../../services/share_service.dart';
import '../../services/company_offer_service.dart';
import '../../core/config/business_categories.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _service = LoyaltyProgramService();
  final _offerService = CompanyOfferService();
  final _profileService = ProfileService();
  final _locationService = LocationService();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _searchController = TextEditingController();

  bool _loading = true;
  bool _gettingLocation = false;
  bool _locationInitialized = false;
  String? _error;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _promotions = [];
  List<Map<String, dynamic>> _offers = [];
  String _categoryFilter = 'Todas';
  Set<String> _customerInterests = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeLocationAndLoad();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocationAndLoad() async {
    try {
      final profile = await _profileService.getProfile();
      final savedCity = profile?['city']?.toString() ?? '';
      final savedState = profile?['state']?.toString() ?? '';
      _customerInterests = Set<String>.from(profile?['customer_interests'] ?? const []);
      if (savedCity.trim().isNotEmpty) {
        _cityController.text = savedCity;
        _stateController.text = savedState;
      } else {
        // Sem cidade salva, solicita a localização do dispositivo para
        // mostrar primeiro as empresas próximas. Se a permissão for negada,
        // a tela continua funcionando com busca manual.
        try {
          final location = await _locationService.getCityAndState();
          _cityController.text = location['city'] ?? '';
          _stateController.text = location['state'] ?? '';
        } catch (_) {
          // Não bloquear a exploração caso a localização não esteja disponível.
        }
      }
    } catch (_) {
      // O perfil pode estar indisponível; ainda permitimos busca manual.
    }
    _locationInitialized = true;
    await _load();
  }

  Future<void> _fillLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final location = await _locationService.getCityAndState();
      if (!mounted) return;
      setState(() {
        _cityController.text = location['city'] ?? '';
        _stateController.text = location['state'] ?? '';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _openProfile() async {
    final result = await context.push<bool>('/profile/edit');
    if (result == true && mounted) await _initializeLocationAndLoad();
  }

  Future<void> _load() async {
    if (!_locationInitialized && _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final search = _searchController.text.trim();
      final companiesFuture = _loadCompaniesSafely(city: city, state: state, search: search);
      final promotionsFuture = _loadRewardsSafely(city: city, state: state, search: search);
      final offersFuture = _offerService.getPublicOffers().catchError(
        (_) => <Map<String, dynamic>>[],
      );
      final results = await Future.wait([
        companiesFuture,
        promotionsFuture,
        offersFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _companies = results[0];
        _promotions = results[1];
        _companies.sort((a, b) {
          final aInterested = _customerInterests.contains(a['category']?.toString());
          final bInterested = _customerInterests.contains(b['category']?.toString());
          return (bInterested ? 1 : 0).compareTo(aInterested ? 1 : 0);
        });
        _promotions.sort((a, b) {
          final companyA = Map<String, dynamic>.from(a['company'] ?? a['companies'] ?? {});
          final companyB = Map<String, dynamic>.from(b['company'] ?? b['companies'] ?? {});
          final aInterested = _customerInterests.contains(companyA['category']?.toString());
          final bInterested = _customerInterests.contains(companyB['category']?.toString());
          return (bInterested ? 1 : 0).compareTo(aInterested ? 1 : 0);
        });
        _offers = results[2].where((offer) {
          final company = Map<String, dynamic>.from(offer['companies'] ?? {});
          final cityMatch = city.isEmpty || (company['city']?.toString().toLowerCase() ?? '').contains(city.toLowerCase());
          final stateMatch = state.isEmpty || (company['state']?.toString().toUpperCase() ?? '') == state.toUpperCase();
          final normalizedSearch = search.toLowerCase();
          final searchMatch = search.isEmpty ||
              (offer['title']?.toString().toLowerCase().contains(normalizedSearch) ?? false) ||
              (offer['description']?.toString().toLowerCase().contains(normalizedSearch) ?? false) ||
              (company['name']?.toString().toLowerCase().contains(normalizedSearch) ?? false) ||
              (company['category']?.toString().toLowerCase().contains(normalizedSearch) ?? false);
          return cityMatch && stateMatch && searchMatch;
        }).toList();
        _offers.sort((a, b) {
          final companyA = Map<String, dynamic>.from(a['companies'] ?? {});
          final companyB = Map<String, dynamic>.from(b['companies'] ?? {});
          final aInterested = _customerInterests.contains(companyA['category']?.toString());
          final bInterested = _customerInterests.contains(companyB['category']?.toString());
          return (bInterested ? 1 : 0).compareTo(aInterested ? 1 : 0);
        });
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

  Future<List<Map<String, dynamic>>> _loadCompaniesSafely({required String city, required String state, required String search}) async {
    try {
      return await _service.discoverCompanies(city: city, state: state, search: search);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRewardsSafely({required String city, required String state, required String search}) async {
    try {
      return await _service.discoverPromotions(city: city, state: state, search: search);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> get _filteredCompanies => _companies.where((company) =>
      _categoryFilter == 'Todas' || company['category']?.toString() == _categoryFilter).toList();

  List<Map<String, dynamic>> get _filteredOffers => _offers.where((offer) {
    final company = Map<String, dynamic>.from(offer['companies'] ?? {});
    return _categoryFilter == 'Todas' || company['category']?.toString() == _categoryFilter;
  }).toList();

  List<Map<String, dynamic>> get _filteredPromotions => _promotions.where((promotion) {
    final points = (promotion['points_required'] as num?)?.toInt() ?? 0;
    if (points <= 0) return false; // Zero-point rewards are now represented as offers.
    final company = Map<String, dynamic>.from(promotion['company'] ?? promotion['companies'] ?? {});
    return _categoryFilter == 'Todas' || company['category']?.toString() == _categoryFilter;
  }).toList();

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: _categoryFilter == 'Todas',
            onSelected: (_) => setState(() => _categoryFilter = 'Todas'),
          ),
          ...businessCategories.map((category) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              label: Text(category),
              selected: _categoryFilter == category,
              onSelected: (_) => setState(() => _categoryFilter = category),
            ),
          )),
        ],
      ),
    );
  }


  Future<void> _openLoyaltyProgram(Map<String, dynamic> company) async {
    final left = await context.push<bool>(
      '/customer/loyalty-program',
      extra: company,
    );
    if (left == true && mounted) await _load();
  }

  Future<void> _join(Map<String, dynamic> company) async {
    try {
      await _service.joinProgram(company['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agora você participa da fidelidade de ${company['name']}!',
          ),
        ),
      );
      await _load();
      if (!mounted) return;
      _openLoyaltyProgram(company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final locationSummary = [city, state]
        .where((value) => value.isNotEmpty)
        .join(' - ');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Descobrir')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Empresa ou promoção',
                      hintText: 'Digite o nome da empresa ou promoção',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Pesquisar',
                        icon: const Icon(Icons.search),
                        onPressed: _load,
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                  const SizedBox(height: 4),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      leading: const Icon(Icons.filter_alt_outlined),
                      title: const Text(
                        'Filtrar por cidade e estado',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        locationSummary.isEmpty
                            ? 'Opcional — pesquisar em qualquer localização'
                            : locationSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      initiallyExpanded: false,
                      children: [
                        if (city.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Informe sua cidade ou use sua localização para encontrar empresas próximas.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        TextField(
                          controller: _cityController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Cidade',
                            hintText: 'Ex.: Tucuruí',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _stateController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 2,
                                decoration: const InputDecoration(
                                  labelText: 'UF',
                                  hintText: 'PA',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.map_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _load(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Usar minha localização',
                              onPressed: _gettingLocation
                                  ? null
                                  : _fillLocation,
                              icon: _gettingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.search),
                            label: const Text('Aplicar filtros'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildCategoryFilters(),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.storefront_outlined), text: 'Empresas'),
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Ofertas'),
              Tab(icon: Icon(Icons.card_giftcard_outlined), text: 'Recompensas'),
              ],
              labelPadding: EdgeInsets.symmetric(horizontal: 8),
              isScrollable: false,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCompanyResults(),
                  _buildOfferResults(),
                  _buildPromotionResults(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildRefreshableMessage(_error!);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_filteredCompanies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nenhuma empresa encontrada nesta categoria/localização.')),
            )
          else
            ..._filteredCompanies.map(_companyCard),
        ],
      ),
    );
  }

  Widget _buildOfferResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildRefreshableMessage(_error!);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_filteredOffers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nenhuma oferta disponível nesta categoria.')),
            ),
          ..._filteredOffers.map((offer) {
            final company = Map<String, dynamic>.from(offer['companies'] ?? {});
            final image = offer['image_url']?.toString() ?? '';
            final endDate = DateTime.tryParse(offer['ends_at']?.toString() ?? '')?.toLocal();
            final validUntil = endDate == null
                ? 'Validade não informada'
                : 'Válida até ${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image.isNotEmpty)
                    Image.network(
                      image,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (company['logo_url']?.toString() ?? '').isNotEmpty
                          ? NetworkImage(company['logo_url'].toString())
                          : null,
                      child: (company['logo_url']?.toString() ?? '').isEmpty
                          ? const Icon(Icons.storefront)
                          : null,
                    ),
                    title: Text(company['name']?.toString() ?? 'Empresa'),
                    subtitle: Text(
                      [company['city'], company['state']]
                          .where((value) => value != null && value.toString().isNotEmpty)
                          .join(' - '),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['title']?.toString() ?? 'Oferta',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if ((offer['description']?.toString() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(offer['description'].toString()),
                        ],
                        const SizedBox(height: 6),
                        Text(validUntil, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/empresa/${company['id']}?oferta=${offer['id']}'),
                                icon: const Icon(Icons.store_outlined),
                                label: const Text('Ver empresa'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Compartilhar oferta',
                              onPressed: () => ShareService.shareOffer(
                                companyName: company['name']?.toString() ?? 'Empresa',
                                title: offer['title']?.toString() ?? 'Oferta',
                                description: offer['description']?.toString(),
                                companyLogoUrl: company['logo_url']?.toString(),
                                companyId: company['id']?.toString(),
                                offerId: offer['id']?.toString(),
                              ),
                              icon: const Icon(Icons.share_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPromotionResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildRefreshableMessage(_error!);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_filteredPromotions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma promoção disponível nesta localização no momento.',
                ),
              ),
            )
          else
            ..._filteredPromotions.map(_promotionCard),
        ],
      ),
    );
  }

  Widget _buildRefreshableMessage(String message) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [Text(message, textAlign: TextAlign.center)],
      ),
    );
  }

  Widget _companyCard(Map<String, dynamic> company) {
    final city = [
      company['city'],
      company['state'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' - ');
    final joined = company['joined'] == true;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final left = await context.push<bool>(
          '/customer/company-details',
          extra: company,
        );
        if (left == true && mounted) await _load();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        (company['logo_url'] ?? '').toString().isNotEmpty
                        ? NetworkImage(company['logo_url'].toString())
                        : null,
                    child: (company['logo_url'] ?? '').toString().isNotEmpty
                        ? null
                        : const Icon(Icons.storefront_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      company['name']?.toString() ?? 'Empresa',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (city.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    city,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if ((company['category']?.toString() ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.category_outlined, size: 16),
                    label: Text(company['category'].toString()),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: joined
                    ? OutlinedButton.icon(
                        onPressed: () => _openLoyaltyProgram(company),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Ver minha fidelidade'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _join(company),
                        icon: const Icon(Icons.add),
                        label: const Text('Participar da fidelidade'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promotionCard(Map<String, dynamic> promotion) {
    final company = Map<String, dynamic>.from(promotion['company'] ?? {});
    final type = promotion['type']?.toString();
    final discount = promotion['discount_percentage'];
    final reward = type == 'discount' && discount != null
        ? '${(discount as num).toStringAsFixed(0)}% de desconto'
        : (promotion['gift_description']?.toString().trim().isNotEmpty == true
              ? promotion['gift_description'].toString()
              : 'Recompensa especial');
    final location = [
      company['city'],
      company['state'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' - ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((promotion['image_url'] ?? '').toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  promotion['image_url'].toString(),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                const Icon(Icons.local_offer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    promotion['title']?.toString() ?? 'Promoção',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Compartilhar recompensa',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ShareService.sharePromotion(
                    companyName: company['name']?.toString() ?? 'Empresa',
                    title: promotion['title']?.toString() ?? 'Recompensa',
                    type: type ?? '',
                    discountPercentage: discount?.toString(),
                    giftDescription: promotion['gift_description']?.toString(),
                    description: promotion['description']?.toString(),
                    companyLogoUrl: company['logo_url']?.toString(),
                    companyId: company['id']?.toString(),
                  ),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reward,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if ((promotion['description'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(promotion['description'].toString()),
              ),
            const SizedBox(height: 8),
            Text(
              'Disponível em ${company['name'] ?? 'Empresa'}${location.isEmpty ? '' : ' • $location'}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
            'Resgate: ${promotion['points_required'] ?? 1} pontos',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Builder(
                builder: (context) {
                  final match = _companies
                      .where(
                        (c) => c['id'].toString() == company['id']?.toString(),
                      )
                      .toList();
                  final joined =
                      match.isNotEmpty && match.first['joined'] == true;
                  final companyForAction = match.isNotEmpty
                      ? match.first
                      : <String, dynamic>{...company, 'joined': false};
                  return TextButton.icon(
                    onPressed: () {
                      if (joined) {
                        _openLoyaltyProgram(companyForAction);
                      } else {
                        _join(companyForAction);
                      }
                    },
                    icon: Icon(joined ? Icons.check_circle_outline : Icons.add),
                    label: Text(
                      joined
                          ? 'Ver minha fidelidade'
                          : 'Participar da fidelidade',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
