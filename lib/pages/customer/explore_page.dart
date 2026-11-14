import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/location_service.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/profile_service.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _service = LoyaltyProgramService();
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
    setState(() { _loading = true; _error = null; });
    try {
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final search = _searchController.text.trim();
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _service.discoverCompanies(city: city, state: state, search: search),
        _service.discoverPromotions(city: city, state: state, search: search),
      ]);
      if (!mounted) return;
      setState(() {
        _companies = results[0];
        _promotions = results[1];
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

  Future<void> _join(Map<String, dynamic> company) async {
    try {
      await _service.joinProgram(company['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agora você participa da fidelidade de ${company['name']}!')),
      );
      await _load();
      if (!mounted) return;
      context.push('/customer/loyalty-program', extra: company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar empresas')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            if (_cityController.text.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Informe sua cidade ou permita o acesso à localização para ver empresas próximas.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
            TextField(
              controller: _cityController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Cidade', hintText: 'Ex.: Tucuruí',
                prefixIcon: Icon(Icons.location_on_outlined), border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: _stateController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'UF', hintText: 'PA', counterText: '',
                  prefixIcon: Icon(Icons.map_outlined), border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _load(),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Usar minha localização',
                onPressed: _gettingLocation ? null : _fillLocation,
                icon: _gettingLocation
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Empresa ou promoção', prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _load),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: _load, icon: const Icon(Icons.filter_alt_outlined), label: const Text('Buscar'),
            )),
          ]),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _sectionTitle('Empresas', Icons.storefront_outlined, _companies.length),
                        if (_companies.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Nenhuma empresa encontrada nesta localização.'))
                        else
                          ..._companies.map(_companyCard),
                        const SizedBox(height: 18),
                        _sectionTitle('Promoções e descontos', Icons.local_offer_outlined, _promotions.length),
                        if (_promotions.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Nenhuma promoção disponível nesta localização no momento.'))
                        else
                          ..._promotions.map(_promotionCard),
                      ],
                    ),
                  )),
      ]),
    );
  }

  Widget _sectionTitle(String title, IconData icon, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))), Text('$count')]),
  );

  Widget _companyCard(Map<String, dynamic> company) {
    final city = [company['city'], company['state']]
        .where((v) => v != null && v.toString().isNotEmpty).join(' - ');
    final joined = company['joined'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(Icons.storefront_outlined)),
            const SizedBox(width: 12),
            Expanded(child: Text(company['name']?.toString() ?? 'Empresa', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ]),
          if (city.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(city, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
          if ((company['description'] ?? '').toString().trim().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(company['description'].toString())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: joined
              ? OutlinedButton.icon(onPressed: () => context.push('/customer/loyalty-program', extra: company), icon: const Icon(Icons.check_circle_outline), label: const Text('Ver minha fidelidade'))
              : FilledButton.icon(onPressed: () => _join(company), icon: const Icon(Icons.add), label: const Text('Participar da fidelidade'))),
        ]),
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
            ? promotion['gift_description'].toString() : 'Benefício especial');
    final location = [company['city'], company['state']]
        .where((v) => v != null && v.toString().isNotEmpty).join(' - ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_offer_outlined), const SizedBox(width: 8),
            Expanded(child: Text(promotion['title']?.toString() ?? 'Promoção', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Text(reward, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          if ((promotion['description'] ?? '').toString().trim().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(promotion['description'].toString())),
          const SizedBox(height: 8),
          Text('Disponível em ${company['name'] ?? 'Empresa'}${location.isEmpty ? '' : ' • $location'}', style: const TextStyle(color: Colors.grey)),
          Text('Resgate: ${promotion['points_required'] ?? 0} pontos', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: Builder(builder: (context) {
            final match = _companies.where((c) => c['id'].toString() == company['id']?.toString()).toList();
            final joined = match.isNotEmpty && match.first['joined'] == true;
            final companyForAction = match.isNotEmpty
                ? match.first
                : <String, dynamic>{...company, 'joined': false};
            return TextButton.icon(
              onPressed: () {
                if (joined) {
                  context.push('/customer/loyalty-program', extra: companyForAction);
                } else {
                  _join(companyForAction);
                }
              },
              icon: Icon(joined ? Icons.check_circle_outline : Icons.add),
              label: Text(joined ? 'Ver minha fidelidade' : 'Participar da fidelidade'),
            );
          })),
        ]),
      ),
    );
  }
}
