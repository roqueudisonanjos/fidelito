import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/admin_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _adminService.getCustomers(query: _searchController.text),
        _adminService.getCompanies(query: _searchController.text),
      ]);
      if (!mounted) return;
      setState(() {
        _customers = results[0];
        _companies = results[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _generateRecoveryLink(Map<String, dynamic> customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerar link de recuperação?'),
        content: Text(
          'Antes de continuar, confirme que você verificou a identidade de '
          '${customer['full_name'] ?? 'do cliente'} por um canal confiável. '
          'O link será de uso único e deve ser enviado somente ao titular da conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar e gerar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = customer['id'].toString();
    setState(() => _busyId = id);
    try {
      final link = await _adminService.generateRecoveryLink(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Link de recuperação gerado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conta: ${customer['email'] ?? 'E-mail não informado'}'),
              const SizedBox(height: 12),
              const Text(
                'Copie o link e envie diretamente ao cliente após confirmar sua identidade. '
                'O link é temporário e pode ser usado uma única vez.',
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: SingleChildScrollView(child: SelectableText(link)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Link copiado. Envie somente ao titular da conta.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar link'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _generateCompanyRecoveryLink(
    Map<String, dynamic> company,
  ) async {
    final companyName = company['name']?.toString() ?? 'esta empresa';
    final ownerName = company['owner_name']?.toString() ?? 'responsável';
    final ownerEmail = company['owner_email']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerar link de recuperação?'),
        content: Text(
          'Este link permitirá que $ownerName redefina a senha da conta responsável por "$companyName". '
          'Antes de continuar, confirme a identidade do responsável por um canal confiável. '
          'O link é temporário e de uso único.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar e gerar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = company['id'].toString();
    setState(() => _busyId = id);
    try {
      final link = await _adminService.generateCompanyRecoveryLink(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Link de recuperação gerado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Empresa: $companyName'),
              const SizedBox(height: 4),
              Text('Responsável: $ownerName'),
              Text(
                'E-mail: ${ownerEmail.isNotEmpty ? ownerEmail : 'Não informado'}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Envie este link somente ao responsável após confirmar sua identidade. '
                'Ele é temporário e pode ser usado uma única vez.',
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: SingleChildScrollView(child: SelectableText(link)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Link copiado. Envie somente ao responsável da empresa.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar link'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteCompanyAccount(Map<String, dynamic> company) async {
    final companyName = company['name']?.toString() ?? 'esta empresa';
    final ownerName =
        company['owner_name']?.toString() ?? 'responsável não identificado';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta da empresa?'),
        content: Text(
          'Esta ação é permanente. A conta de "$companyName" e o acesso de $ownerName serão excluídos. '
          'As participações dos clientes serão encerradas, os pontos restantes serão zerados e os clientes serão notificados. '
          'Os registros empresariais e históricos necessários permanecerão preservados. '
          'Se este responsável possuir outras empresas vinculadas, elas também serão encerradas. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = company['id'].toString();
    setState(() => _busyId = id);
    try {
      await _adminService.deleteCompanyAccount(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conta da empresa excluída. Clientes notificados e acesso encerrado.',
          ),
        ),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _toggleCompany(Map<String, dynamic> company) async {
    final currentlyActive = company['active'] == true;
    final nextActive = !currentlyActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nextActive ? 'Ativar empresa?' : 'Desativar empresa?'),
        content: Text(
          nextActive
              ? 'A empresa ${company['name']} voltará a aparecer e poderá utilizar os recursos do Fidelito.'
              : 'A empresa ${company['name']} será suspensa. O responsável perderá o acesso ao aplicativo, e todos os clientes ativos receberão uma notificação informando que não poderão utilizar os pontos enquanto o programa estiver suspenso. Os saldos serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(nextActive ? 'Ativar' : 'Desativar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = company['id'].toString();
    setState(() => _busyId = id);
    try {
      await _adminService.setCompanyActive(companyId: id, active: nextActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive
                ? 'Empresa reativada e acesso liberado.'
                : 'Empresa suspensa. Clientes notificados e acesso bloqueado.',
          ),
        ),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _dateLabel(dynamic value) {
    if (value == null) return 'Data não disponível';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'Data não disponível';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    if (_customers.isEmpty)
      return const _EmptyState(message: 'Nenhum cliente encontrado.');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: _customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final id = customer['id'].toString();
        final isBusy = _busyId == id;
        final name = customer['full_name']?.toString() ?? 'Cliente sem nome';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
                      backgroundImage:
                          (customer['avatar_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(customer['avatar_url'].toString())
                          : null,
                      child:
                          (customer['avatar_url'] ?? '').toString().isNotEmpty
                          ? null
                          : Text(
                              name.isEmpty
                                  ? '?'
                                  : name.substring(0, 1).toUpperCase(),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer['email']?.toString().isNotEmpty == true
                                ? customer['email'].toString()
                                : 'Sem e-mail',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _MetaItem(
                      icon: Icons.phone_outlined,
                      text: customer['phone']?.toString().isNotEmpty == true
                          ? customer['phone'].toString()
                          : 'Sem telefone',
                    ),
                    _MetaItem(
                      icon: Icons.calendar_today_outlined,
                      text: 'Cadastro: ${_dateLabel(customer['created_at'])}',
                    ),
                    _MetaItem(
                      icon: customer['email_confirmed'] == true
                          ? Icons.verified_outlined
                          : Icons.info_outline,
                      text: customer['email_confirmed'] == true
                          ? 'E-mail confirmado'
                          : 'E-mail não confirmado',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _generateRecoveryLink(customer),
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset_rounded),
                    label: const Text('Gerar link de recuperação de senha'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyList() {
    if (_companies.isEmpty)
      return const _EmptyState(message: 'Nenhuma empresa encontrada.');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: _companies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final company = _companies[index];
        final id = company['id'].toString();
        final active = company['active'] == true;
        final isBusy = _busyId == id;
        final location = [
          company['city'],
          company['state'],
        ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' - ');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.secondaryLight,
                      backgroundImage:
                          (company['logo_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(company['logo_url'].toString())
                          : null,
                      child: (company['logo_url'] ?? '').toString().isNotEmpty
                          ? null
                          : const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.warning,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company['name']?.toString() ?? 'Empresa sem nome',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryLight
                            : AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        company['deleted_at'] != null
                            ? 'Excluída'
                            : (active
                                  ? 'Ativa'
                                  : (company['suspended_at'] != null
                                        ? 'Suspensa'
                                        : 'Pendente')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.primaryDark
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetaItem(
                  icon: Icons.person_outline_rounded,
                  text:
                      company['owner_name']?.toString() ??
                      'Responsável não identificado',
                ),
                const SizedBox(height: 5),
                _MetaItem(
                  icon: Icons.email_outlined,
                  text: company['owner_email']?.toString().isNotEmpty == true
                      ? company['owner_email'].toString()
                      : 'Sem e-mail do responsável',
                ),
                if (company['phone']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  _MetaItem(
                    icon: Icons.phone_outlined,
                    text: company['phone'].toString(),
                  ),
                ],
                const SizedBox(height: 12),
                if (company['deleted_at'] == null &&
                    company['owner_id'] != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _generateCompanyRecoveryLink(company),
                      icon: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_rounded),
                      label: const Text('Gerar link de recuperação de senha'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : () => _toggleCompany(company),
                      icon: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              active
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                      label: Text(
                        active ? 'Desativar empresa' : 'Ativar empresa',
                      ),
                    ),
                  ),
                  if (!active && company['suspended_at'] != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: isBusy
                            ? null
                            : () => _deleteCompanyAccount(company),
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever_outlined),
                        label: const Text('Excluir conta da empresa'),
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Conta excluída. Os registros históricos foram preservados.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel administrativo'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Clientes'),
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Empresas'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bem-vindo à administração',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Gerencie contas e empresas do Fidelito.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryCard(
                        icon: Icons.people_alt_outlined,
                        label: 'Clientes listados',
                        count: _customers.length,
                      ),
                      const SizedBox(width: 10),
                      _buildSummaryCard(
                        icon: Icons.storefront_outlined,
                        label: 'Empresas listadas',
                        count: _companies.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadData(),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, e-mail, telefone ou cidade',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: AppColors.error.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        RefreshIndicator(
                          onRefresh: _loadData,
                          child: _buildCustomerList(),
                        ),
                        RefreshIndicator(
                          onRefresh: _loadData,
                          child: _buildCompanyList(),
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedText),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Icon(
          Icons.search_off_rounded,
          size: 42,
          color: AppColors.mutedText.withValues(alpha: .7),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
      ],
    );
  }
}
