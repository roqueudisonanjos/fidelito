import 'package:flutter/material.dart';

import '../../services/benefit_service.dart';
import '../../services/dashboard_service.dart';

class ValidateBenefitPage extends StatefulWidget {
  const ValidateBenefitPage({super.key});

  @override
  State<ValidateBenefitPage> createState() => _ValidateBenefitPageState();
}

class _ValidateBenefitPageState extends State<ValidateBenefitPage>
    with SingleTickerProviderStateMixin {
  final BenefitService _benefitService = BenefitService();
  final DashboardService _dashboardService = DashboardService();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _historyCustomerController = TextEditingController();
  final TextEditingController _historyPromotionController = TextEditingController();
  DateTimeRange? _historyDateRange;
  late final TabController _tabController;

  bool _loadingCustomers = true;
  bool _loadingBenefits = false;
  bool _loadingCode = false;
  bool _loadingHistory = true;
  bool _validating = false;
  String? _error;
  String? _historyError;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _benefits = [];
  List<Map<String, dynamic>> _usedBenefits = [];
  Map<String, dynamic>? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomers();
    _loadUsedBenefits();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loadingCustomers = true;
      _error = null;
    });
    try {
      final customers = await _dashboardService.getCompanyCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCustomers = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _loadUsedBenefits() async {
    setState(() => _loadingHistory = true);
    try {
      final benefits = await _benefitService.getUsedBenefitsForCompany();
      if (!mounted) return;
      setState(() {
        _usedBenefits = benefits;
        _loadingHistory = false;
        _historyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = _cleanError(e);
      });
    }
  }

  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    setState(() {
      _selectedCustomer = customer;
      _loadingBenefits = true;
      _benefits = [];
      _error = null;
    });
    try {
      final benefits = await _benefitService
          .getAvailableBenefitsForCustomer(customer['id'].toString());
      if (!mounted) return;
      setState(() {
        _benefits = benefits;
        _loadingBenefits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBenefits = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _lookupByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Informe o código da recompensa.');
      return;
    }
    setState(() {
      _loadingCode = true;
      _error = null;
    });
    try {
      final benefit = await _benefitService.getBenefitById(code);
      if (!mounted) return;
      setState(() => _loadingCode = false);
      if (benefit == null) {
        setState(() => _error = 'Não encontramos uma recompensa com esse código.');
        return;
      }
      await _confirmBenefit(benefit);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCode = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _confirmBenefit(Map<String, dynamic> benefit) async {
    if (benefit['status'] != 'available') {
      setState(() => _error = benefit['status'] == 'used'
          ? 'Esta recompensa já foi utilizada.'
          : 'Esta recompensa não está disponível.');
      return;
    }

    final promotion = benefit['promotions'] as Map<String, dynamic>?;
    final customer = benefit['profiles'] as Map<String, dynamic>? ??
        _selectedCustomer;
    final title = promotion?['title']?.toString() ?? 'Recompensa';
    final customerName = customer?['full_name']?.toString() ?? 'Cliente';
    final points = benefit['points_spent'] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar utilização'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundImage: (customer?['avatar_url'] ?? '').toString().isNotEmpty
                    ? NetworkImage(customer!['avatar_url'].toString())
                    : null,
                child: (customer?['avatar_url'] ?? '').toString().isEmpty
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 20),
            const Text('RECOMPENSA', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('$points pontos utilizados'),
            const SizedBox(height: 16),
            const Text('Confirma que o cliente está utilizando esta recompensa agora?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Voltar')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirmar utilização'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _useBenefit(benefit['id'].toString());
    }
  }

  Future<void> _useBenefit(String redemptionId) async {
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      await _benefitService.useBenefit(redemptionId);
      if (!mounted) return;
      setState(() => _validating = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
          title: const Text('Recompensa validada!'),
          content: const Text('A recompensa foi marcada como utilizada com sucesso.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
        ),
      );
      _codeController.clear();
      await _loadUsedBenefits();
      if (_selectedCustomer != null) {
        await _selectCustomer(_selectedCustomer!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _error = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  List<Map<String, dynamic>> get _filteredUsedBenefits {
    final customerQuery = _historyCustomerController.text.trim().toLowerCase();
    final promotionQuery = _historyPromotionController.text.trim().toLowerCase();
    final range = _historyDateRange;

    return _usedBenefits.where((item) {
      final customer = item['profiles'] as Map<String, dynamic>?;
      final promotion = item['promotions'] as Map<String, dynamic>?;
      final customerName = (customer?['full_name'] ?? '').toString().toLowerCase();
      final whatsapp = (customer?['whatsapp'] ?? '').toString().toLowerCase();
      final promotionName = (promotion?['title'] ?? '').toString().toLowerCase();
      final usedAtValue = item['used_at'] ?? item['redeemed_at'];
      final usedAt = DateTime.tryParse(usedAtValue?.toString() ?? '')?.toLocal();

      final matchesCustomer = customerQuery.isEmpty ||
          customerName.contains(customerQuery) || whatsapp.contains(customerQuery);
      final matchesPromotion = promotionQuery.isEmpty || promotionName.contains(promotionQuery);
      final matchesDate = range == null || (usedAt != null &&
          !usedAt.isBefore(DateTime(range.start.year, range.start.month, range.start.day)) &&
          !usedAt.isAfter(DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59)));

      return matchesCustomer && matchesPromotion && matchesDate;
    }).toList();
  }

  Future<void> _chooseHistoryDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _historyDateRange,
      helpText: 'Filtrar período do histórico',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked != null && mounted) {
      setState(() => _historyDateRange = picked);
    }
  }

  void _clearHistoryFilters() {
    setState(() {
      _historyCustomerController.clear();
      _historyPromotionController.clear();
      _historyDateRange = null;
    });
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _customers;
    return _customers.where((customer) {
      final name = (customer['full_name'] ?? '').toString().toLowerCase();
      final whatsapp = (customer['whatsapp'] ?? '').toString().toLowerCase();
      return name.contains(query) || whatsapp.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _searchController.dispose();
    _historyCustomerController.dispose();
    _historyPromotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar recompensa'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Escolher cliente'),
            Tab(icon: Icon(Icons.tag), text: 'Usar código'),
            Tab(icon: Icon(Icons.history), text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCustomerTab(), _buildCodeTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildCustomerTab() {
    if (_selectedCustomer != null) return _buildCustomerBenefits();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Selecione o cliente', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Encontre o cliente e escolha uma recompensa que ele já resgatou.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou WhatsApp',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                  onPressed: () { _searchController.clear(); setState(() {}); },
                  icon: const Icon(Icons.close),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
        Expanded(child: _loadingCustomers
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView(_error!, _loadCustomers)
                : _filteredCustomers.isEmpty
                    ? _emptyState(Icons.person_search, 'Nenhum cliente encontrado', 'Os clientes que participam do programa aparecerão aqui.')
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: _filteredCustomers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final avatar = (customer['avatar_url'] ?? '').toString();
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                  child: avatar.isEmpty ? const Icon(Icons.person_outline) : null,
                                ),
                                title: Text(customer['full_name']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(customer['whatsapp']?.toString() ?? 'Cliente Fidelito'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _selectCustomer(customer),
                              ),
                            );
                          },
                        ),
                      )),
      ],
    );
  }

  Widget _buildCustomerBenefits() {
    final customer = _selectedCustomer!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(children: [
          IconButton(onPressed: () => setState(() { _selectedCustomer = null; _benefits = []; _error = null; }), icon: const Icon(Icons.arrow_back)),
          CircleAvatar(
            backgroundImage: (customer['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(customer['avatar_url'].toString()) : null,
            child: (customer['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.person_outline) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer['full_name']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const Text('Recompensas disponíveis', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          IconButton(onPressed: () => _selectCustomer(customer), icon: const Icon(Icons.refresh), tooltip: 'Atualizar'),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _loadingBenefits
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(_error!, () => _selectCustomer(customer))
              : _benefits.isEmpty
                  ? _emptyState(Icons.card_giftcard, 'Nenhuma recompensa pendente', 'Este cliente não possui recompensas disponíveis para utilização.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _benefits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final benefit = _benefits[index];
                        final promotion = benefit['promotions'] as Map<String, dynamic>?;
                        final title = promotion?['title']?.toString() ?? 'Recompensa';
                        final points = benefit['points_spent'] ?? 0;
                        final description = promotion?['description']?.toString();
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                const Icon(Icons.check_circle_outline, color: Colors.green),
                              ]),
                              if (description != null && description.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                              const SizedBox(height: 12),
                              Text('$points pontos utilizados', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 14),
                              SizedBox(width: double.infinity, child: FilledButton.icon(
                                onPressed: _validating ? null : () => _confirmBenefit({...benefit, 'profiles': customer}),
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Validar esta recompensa'),
                              )),
                            ]),
                          ),
                        );
                      },
                    )),
    ]);
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recompensas utilizadas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text('Consulte quem utilizou cada recompensa e quando.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadingHistory ? null : _loadUsedBenefits,
                tooltip: 'Atualizar histórico',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _historyCustomerController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Filtrar por cliente ou WhatsApp',
                  prefixIcon: const Icon(Icons.person_search_outlined),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: _historyPromotionController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Filtrar por recompensa',
                  prefixIcon: const Icon(Icons.card_giftcard_outlined),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chooseHistoryDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_historyDateRange == null
                          ? 'Selecionar período'
                          : '${_historyDateRange!.start.day.toString().padLeft(2, '0')}/${_historyDateRange!.start.month.toString().padLeft(2, '0')}/${_historyDateRange!.start.year} – ${_historyDateRange!.end.day.toString().padLeft(2, '0')}/${_historyDateRange!.end.month.toString().padLeft(2, '0')}/${_historyDateRange!.end.year}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (_historyCustomerController.text.isEmpty &&
                            _historyPromotionController.text.isEmpty && _historyDateRange == null)
                        ? null
                        : _clearHistoryFilters,
                    tooltip: 'Limpar filtros',
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _historyError != null
                  ? _errorView(_historyError!, _loadUsedBenefits)
                  : _filteredUsedBenefits.isEmpty
                  ? _emptyState(Icons.filter_list_off, _usedBenefits.isEmpty ? 'Nenhuma recompensa utilizada' : 'Nenhum resultado encontrado', _usedBenefits.isEmpty ? 'Quando um cliente utilizar uma recompensa, ela aparecerá aqui.' : 'Tente alterar ou limpar os filtros para ver outros registros.')
                  : RefreshIndicator(
                      onRefresh: _loadUsedBenefits,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: _filteredUsedBenefits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = _filteredUsedBenefits[index];
                          final promotion = item['promotions'] as Map<String, dynamic>?;
                          final customer = item['profiles'] as Map<String, dynamic>?;
                          final title = promotion?['title']?.toString() ?? 'Recompensa';
                          final name = customer?['full_name']?.toString() ?? 'Cliente';
                          final whatsapp = customer?['whatsapp']?.toString() ?? '';
                          final dateValue = item['used_at'] ?? item['redeemed_at'];
                          final date = DateTime.tryParse(dateValue?.toString() ?? '')?.toLocal();
                          final dateLabel = date == null
                              ? 'Data não informada'
                              : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          final avatar = customer?['avatar_url']?.toString() ?? '';
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              leading: CircleAvatar(
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty ? const Icon(Icons.person_outline) : null,
                              ),
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text('$name${whatsapp.isEmpty ? '' : ' • $whatsapp'}\n$dateLabel\n${item['points_spent'] ?? 0} pontos utilizados'),
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCodeTab() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.pin_outlined, size: 54),
      const SizedBox(height: 16),
      const Text('Validar pelo código', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Se preferir, digite o código que aparece na recompensa do cliente.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24),
      TextField(
        controller: _codeController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _lookupByCode(),
        decoration: InputDecoration(labelText: 'Código da recompensa', hintText: 'Digite o código', prefixIcon: const Icon(Icons.tag), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      ),
      const SizedBox(height: 14),
      if (_error != null) _errorBanner(_error!),
      SizedBox(height: 52, child: FilledButton.icon(
        onPressed: _loadingCode || _validating ? null : _lookupByCode,
        icon: _loadingCode ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
        label: Text(_loadingCode ? 'Consultando...' : 'Consultar recompensa'),
      )),
    ]);
  }

  Widget _errorView(String message, VoidCallback retry) => Center(
    child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      _errorBanner(message), const SizedBox(height: 12), OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
    ])),
  );

  Widget _errorBanner(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
  );

  Widget _emptyState(IconData icon, String title, String subtitle) => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
    ])),
  );
}
