import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/location_service.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/profile_service.dart';
import '../../services/share_service.dart';
import '../../services/company_offer_service.dart';
import '../../core/config/business_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/floating_image_card.dart';

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

  static const int _descriptionMaxChars = 80;
  static const double _offerImageSize = 110;
  static const EdgeInsets _offerPadding = EdgeInsets.fromLTRB(12, 12, 12, 8);

  String _limitText(String text, [int max = _descriptionMaxChars]) {
    final trimmed = text.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max).trimRight()}…';
  }

  DateTime? _endDate(Map<String, dynamic> item) {
    for (final key in ['ends_at', 'valid_until', 'expires_at']) {
      final value = item[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final date = DateTime.tryParse(value);
      if (date != null) return date.toLocal();
    }
    return null;
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Cabeçalho do card de oferta: logo pequena, nome da empresa e compartilhar.
  Widget _offerHeader(Map<String, dynamic> offer, Map<String, dynamic> company) {
    final logo = company['logo_url']?.toString() ?? '';
    final name = company['name']?.toString() ?? 'Empresa';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 12) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Compartilhar oferta',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: () => ShareService.shareOffer(
            companyName: name,
            title: offer['title']?.toString() ?? 'Oferta',
            description: offer['description']?.toString(),
            companyLogoUrl: company['logo_url']?.toString(),
            companyId: company['id']?.toString(),
            offerId: offer['id']?.toString(),
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  List<FloatBlock> _offerBlocks(Map<String, dynamic> offer) {
    final company = Map<String, dynamic>.from(offer['companies'] ?? {});
    final description = _limitText(offer['description']?.toString() ?? '');
    final endDate = _endDate(offer);
    final validText = endDate == null
        ? 'Validade não informada'
        : 'Válida até ${_formatDateOnly(endDate)}';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;

    return [
      FloatBlock.widget(_offerHeader(offer, company), height: 36, spacing: 6),
      FloatBlock.text(
        offer['title']?.toString() ?? 'Oferta',
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      if (description.isNotEmpty)
        FloatBlock.text(
          description,
          bodyStyle.copyWith(fontSize: 13),
          spacing: 6,
          maxLines: 3,
        ),
      FloatBlock.text(
        validText,
        bodyStyle.copyWith(
          fontSize: 13,
          color: endDate == null ? Colors.grey : Colors.orange,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
      ),
    ];
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final company = Map<String, dynamic>.from(offer['companies'] ?? {});
    final image = offer['image_url']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '/empresa/${company['id']}?oferta=${offer['id']}',
        ),
        child: FloatingImageCard(
          padding: _offerPadding,
          imageUrl: image.isEmpty ? null : image,
          imageSize: _offerImageSize,
          blocks: _offerBlocks(offer),
        ),
      ),
    );
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
          ..._filteredOffers.map(_offerCard),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final left = await context.push<bool>(
            '/customer/company-details',
            extra: _companyForAction(promotion),
          );
          if (left == true && mounted) await _load();
        },
        child: FloatingImageCard(
          padding: _offerPadding,
          blocks: _rewardBlocks(promotion),
        ),
      ),
    );
  }

  Map<String, dynamic> _companyForAction(Map<String, dynamic> promotion) {
    final company = Map<String, dynamic>.from(
      promotion['company'] ?? promotion['companies'] ?? {},
    );
    final match = _companies
        .where((c) => c['id'].toString() == company['id']?.toString())
        .toList();
    return match.isNotEmpty
        ? match.first
        : <String, dynamic>{...company, 'joined': false};
  }

  List<FloatBlock> _rewardBlocks(Map<String, dynamic> promotion) {
    final company = Map<String, dynamic>.from(
      promotion['company'] ?? promotion['companies'] ?? {},
    );
    final type = promotion['type']?.toString();
    final discount = promotion['discount_percentage'];
    final reward = type == 'discount' && discount != null
        ? '${(discount as num).toStringAsFixed(0)}% de desconto'
        : (promotion['gift_description']?.toString().trim().isNotEmpty == true
              ? promotion['gift_description'].toString()
              : 'Recompensa especial');
    final description = _limitText(promotion['description']?.toString() ?? '');
    final endDate = _endDate(promotion);
    final joined = _companyForAction(promotion)['joined'] == true;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;

    return [
      FloatBlock.widget(_rewardHeader(promotion, company), height: 36, spacing: 6),
      FloatBlock.text(
        promotion['title']?.toString() ?? 'Promoção',
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      FloatBlock.text(
        reward,
        bodyStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        spacing: 6,
        maxLines: 1,
        fullWidth: true,
      ),
      if (description.isNotEmpty)
        FloatBlock.text(
          description,
          bodyStyle.copyWith(fontSize: 13),
          spacing: 6,
          maxLines: 3,
        ),
      if (endDate != null)
        FloatBlock.text(
          'Válido até ${_formatDateOnly(endDate)}',
          bodyStyle.copyWith(
            fontSize: 13,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
          spacing: 6,
          maxLines: 1,
        ),
      FloatBlock.text(
        joined
            ? 'Você já participa deste programa.'
            : 'Participe para acumular pontos nesta empresa.',
        bodyStyle.copyWith(
          fontSize: 13,
          color: joined ? Colors.green : Colors.grey,
        ),
        spacing: 8,
        maxLines: 2,
      ),
      FloatBlock.widget(_rewardActions(promotion, joined), height: 40),
    ];
  }

  /// Cabeçalho da recompensa: logo, nome da empresa e compartilhar.
  Widget _rewardHeader(Map<String, dynamic> promotion, Map<String, dynamic> company) {
    final logo = company['logo_url']?.toString() ?? '';
    final name = company['name']?.toString() ?? 'Empresa';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 12) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Compartilhar recompensa',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: () => ShareService.sharePromotion(
            companyName: name,
            title: promotion['title']?.toString() ?? 'Recompensa',
            type: promotion['type']?.toString() ?? '',
            discountPercentage: promotion['discount_percentage']?.toString(),
            giftDescription: promotion['gift_description']?.toString(),
            description: promotion['description']?.toString(),
            companyLogoUrl: company['logo_url']?.toString(),
            companyId: company['id']?.toString(),
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  /// Linha de ações: pontos e botão de participar ou ver fidelidade.
  Widget _rewardActions(Map<String, dynamic> promotion, bool joined) {
    final companyForAction = _companyForAction(promotion);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: joined
                ? Colors.green.withValues(alpha: .12)
                : Colors.grey.withValues(alpha: .12),
          ),
          child: Text(
            '${promotion['points_required'] ?? 1} pts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: joined ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: joined
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _openLoyaltyProgram(companyForAction),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Ver minha fidelidade'),
                  ),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _join(companyForAction),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Participar da fidelidade'),
                  ),
                ),
        ),
      ],
    );
  }

}
