import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/dashboard_service.dart';

class CompanyCustomersPage extends StatefulWidget {
  const CompanyCustomersPage({super.key});

  @override
  State<CompanyCustomersPage> createState() => _CompanyCustomersPageState();
}

class _CompanyCustomersPageState extends State<CompanyCustomersPage> {
  final DashboardService _service = DashboardService();

  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> _customers = [];

  String _search = '';

  @override
  void initState() {
    super.initState();

    _loadCustomers();
  }

  // ============================================================
  // CARREGAR CLIENTES
  // ============================================================

  Future<void> _loadCustomers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final customers = await _service.getCompanyCustomers();

      if (!mounted) return;

      setState(() {
        _customers = customers;
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

  Future<void> _removeCustomer(Map<String, dynamic> customer) async {
    final customerName = (customer['full_name'] ?? 'este cliente').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover cliente do programa?'),
        content: Text(
          'O cliente "$customerName" deixará de aparecer em Meus clientes. '
          'O saldo de pontos deste programa será zerado e o histórico será preservado. '
          'Ele continuará tendo sua conta Plim. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover cliente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _service.removeCustomerFromProgram(customer['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$customerName foi removido do programa.')),
      );
      await _loadCustomers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }


  // ============================================================
  // CLIENTES FILTRADOS
  // ============================================================

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_search.trim().isEmpty) {
      return _customers;
    }

    final search = _search.toLowerCase().trim();

    return _customers.where((customer) {
      final name = (customer['full_name'] ?? '').toString().toLowerCase();

      final whatsapp = (customer['whatsapp'] ?? '').toString().toLowerCase();

      return name.contains(search) || whatsapp.contains(search);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus clientes')),
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
      onRefresh: _loadCustomers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildSearch(),

          const SizedBox(height: 20),

          if (_customers.isEmpty)
            _buildEmpty()
          else if (_filteredCustomers.isEmpty)
            _buildNoSearchResults()
          else
            ..._filteredCustomers.map(_buildCustomerCard),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final count = _customers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clientes',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        Text(
          '$count ${count == 1 ? 'cliente cadastrado' : 'clientes cadastrados'}',
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      ],
    );
  }

  // ============================================================
  // BUSCA
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar cliente...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isNotEmpty
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _search = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // CARD DO CLIENTE
  // ============================================================

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final name = (customer['full_name'] ?? 'Cliente').toString();

    final whatsapp = customer['whatsapp']?.toString();

    final pointsEarned = _toInt(customer['points_earned']);

    final pointsCurrent = _toInt(
      customer['points_current'] ?? customer['points'],
    );

    final lastBenefitUsedAt = customer['last_benefit_used_at']?.toString();

    final available = List<Map<String, dynamic>>.from(
      customer['available_benefits'] ?? [],
    );

    final used = List<Map<String, dynamic>>.from(
      customer['used_benefits'] ?? [],
    );

    final cancelled = List<Map<String, dynamic>>.from(
      customer['cancelled_benefits'] ?? [],
    );

    final hasWhatsApp =
        whatsapp != null && whatsapp.isNotEmpty && whatsapp != 'null';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),

        // ========================================================
        // PARTE ENCOLHIDA
        // ========================================================
        leading: CircleAvatar(
          radius: 23,
          backgroundImage: (customer['avatar_url'] ?? '').toString().isNotEmpty
              ? NetworkImage(customer['avatar_url'].toString())
              : null,
          child: (customer['avatar_url'] ?? '').toString().isNotEmpty
              ? null
              : Text(
                  _initials(name),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),

        title: Text(
          name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        subtitle: Text(
          '$pointsCurrent pontos atuais',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),

        // ========================================================
        // PARTE EXPANDIDA
        // ========================================================
        children: [
          const Divider(height: 1),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // WHATSAPP
          // ------------------------------------------------------
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 20),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      hasWhatsApp ? whatsapp : 'Não cadastrado',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              if (hasWhatsApp)
                FilledButton.icon(
                  onPressed: () => _openWhatsApp(whatsapp),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.history_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Última recompensa utilizada',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastBenefitUsedAt != null && lastBenefitUsedAt.isNotEmpty
                          ? _formatDate(lastBenefitUsedAt)
                          : 'Nenhuma recompensa utilizada',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // PONTOS
          // ------------------------------------------------------
          Row(
            children: [
              Expanded(
                child: _buildPointsCard(
                  icon: Icons.history_rounded,
                  title: 'Pontos recebidos',
                  value: pointsEarned,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildPointsCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Pontos atuais',
                  value: pointsCurrent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAwardPointsDialog(customer),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Adicionar pontos manualmente'),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------------
          // BENEFÍCIOS DISPONÍVEIS
          // ------------------------------------------------------
          _buildBenefitsSection(
            title: 'Recompensas disponíveis',
            icon: Icons.card_giftcard_outlined,
            benefits: available,
            emptyText: 'Nenhuma recompensa disponível.',
            showExpiration: true,
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // BENEFÍCIOS UTILIZADOS
          // ------------------------------------------------------
          _buildBenefitsSection(
            title: 'Recompensas utilizadas',
            icon: Icons.check_circle_outline,
            benefits: used,
            emptyText: 'Nenhuma recompensa utilizada.',
          ),

          // ------------------------------------------------------
          // BENEFÍCIOS CANCELADOS
          // ------------------------------------------------------
          if (cancelled.isNotEmpty) ...[
            const SizedBox(height: 16),

            _buildBenefitsSection(
              title: 'Recompensas canceladas',
              icon: Icons.cancel_outlined,
              benefits: cancelled,
              emptyText: 'Nenhuma recompensa cancelada.',
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _loading ? null : () => _removeCustomer(customer),
              icon: const Icon(Icons.person_remove_alt_1_rounded),
              label: const Text('Remover cliente do programa'),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DE PONTOS
  // ============================================================

  Future<void> _showAwardPointsDialog(Map<String, dynamic> customer) async {
    final pointsController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final customerId =
        customer['customer_id']?.toString() ?? customer['id']?.toString();
    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar este cliente.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar pontos'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cliente: ${customer['full_name'] ?? 'Cliente'}'),
              const SizedBox(height: 14),
              TextFormField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de pontos',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final points = int.tryParse(value ?? '');
                  if (points == null || points <= 0 || points > 10000) {
                    return 'Informe um valor entre 1 e 10.000.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      pointsController.dispose();
      descriptionController.dispose();
      return;
    }

    try {
      final newBalance = await _service.awardPoints(
        customerId: customerId,
        points: int.parse(pointsController.text),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pontos adicionados. Novo saldo: $newBalance pontos.'),
        ),
      );
      await _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      pointsController.dispose();
      descriptionController.dispose();
    }
  }

  Widget _buildPointsCard({
    required IconData icon,
    required String title,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),

          const SizedBox(height: 10),

          Text(
            value.toString(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 3),

          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // BENEFÍCIOS
  // ============================================================

  Widget _buildBenefitsSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> benefits,
    required String emptyText,
    bool showExpiration = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 21),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                '$title (${benefits.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (benefits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              emptyText,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          ...benefits.map(
            (benefit) =>
                _buildBenefitItem(benefit, showExpiration: showExpiration),
          ),
      ],
    );
  }

  // ============================================================
  // ITEM DE BENEFÍCIO
  // ============================================================

  Widget _buildBenefitItem(
    Map<String, dynamic> benefit, {
    bool showExpiration = false,
  }) {
    final title = (benefit['title'] ?? 'Recompensa').toString();

    final points = _toInt(benefit['points_spent']);

    final createdAt = benefit['created_at']?.toString();

    final expiresAt = benefit['expires_at']?.toString();

    final expirationDate = expiresAt != null && expiresAt.isNotEmpty
        ? DateTime.tryParse(expiresAt)
        : null;

    final now = DateTime.now();

    int? daysRemaining;

    if (expirationDate != null) {
      final today = DateTime(now.year, now.month, now.day);

      final expiration = DateTime(
        expirationDate.year,
        expirationDate.month,
        expirationDate.day,
      );

      daysRemaining = expiration.difference(today).inDays;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.card_giftcard, size: 18),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --------------------------------------------------
                // NOME DO BENEFÍCIO
                // --------------------------------------------------
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                // --------------------------------------------------
                // DATA EM QUE FOI RESGATADO
                // --------------------------------------------------
                if (createdAt != null && createdAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Resgatado em ${_formatDate(createdAt)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),

                // --------------------------------------------------
                // DATA DE EXPIRAÇÃO
                // --------------------------------------------------
                if (showExpiration &&
                    expiresAt != null &&
                    expiresAt.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 15),

                      const SizedBox(width: 5),

                      Text(
                        'Expira em ${_formatDate(expiresAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // ------------------------------------------------
                  // AVISO DE VENCIMENTO
                  // ------------------------------------------------
                  if (daysRemaining != null && daysRemaining >= 0) ...[
                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notification_important_outlined,
                          size: 15,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            _expirationMessage(daysRemaining),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),

          // --------------------------------------------------------
          // PONTOS
          // --------------------------------------------------------
          if (points > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '$points pts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // WHATSAPP
  // ============================================================

  Future<void> _openWhatsApp(String whatsapp) async {
    var number = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');

    // Caso o banco tenha armazenado
    // somente DDD + número.
    if (number.length == 10 || number.length == 11) {
      number = '55$number';
    }

    final uri = Uri.parse('https://wa.me/$number');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  // ============================================================
  // ESTADOS VAZIOS
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.6),
            ),

            const SizedBox(height: 16),

            const Text(
              'Nenhum cliente encontrado.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            const Text(
              'Os clientes aparecerão aqui quando tiverem uma conta de fidelidade na sua empresa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 50),

          SizedBox(height: 12),

          Text(
            'Nenhum cliente encontrado para essa busca.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 50),

            const SizedBox(height: 16),

            Text(_error!, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loadCustomers,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _expirationMessage(int daysRemaining) {
    if (daysRemaining == 0) {
      return 'Expira hoje. Entre em contato com o cliente.';
    }

    if (daysRemaining == 1) {
      return 'Expira amanhã. Recomendamos entrar em contato com o cliente.';
    }

    if (daysRemaining <= 7) {
      return 'Faltam $daysRemaining dias. Recomendamos entrar em contato com o cliente.';
    }

    return 'Faltam $daysRemaining dias para o vencimento.';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$day/$month/$year';
  }
}
