import 'package:flutter/material.dart';

import '../../services/report_service.dart';

class CompanyReportsPage extends StatefulWidget {
  const CompanyReportsPage({super.key, required this.companyId});

  final String companyId;

  @override
  State<CompanyReportsPage> createState() => _CompanyReportsPageState();
}

class _CompanyReportsPageState extends State<CompanyReportsPage> {
  final ReportService _service = ReportService();

  final ScrollController _scrollController = ScrollController();

  bool _showScrollToTop = false;

  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>> _transactions = [];

  DateTime? _startDate;

  DateTime? _endDate;

  String _selectedType = 'all';

  int _totalTransactions = 0;

  int _totalPoints = 0;

  int _totalEarned = 0;

  int _totalSpent = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _loadReport();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset >= 300;

    if (shouldShow != _showScrollToTop) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getCompanyReport(
        companyId: widget.companyId,
        startDate: _startDate,
        endDate: _endDate,
        type: _selectedType,
      );

      if (!mounted) return;

      setState(() {
        _transactions = List<Map<String, dynamic>>.from(
          result['transactions'] ?? [],
        );

        _totalTransactions = result['total_transactions'] ?? 0;

        _totalPoints = result['total_points'] ?? 0;

        _totalEarned = result['total_earned'] ?? 0;

        _totalSpent = result['total_spent'] ?? 0;

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

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _startDate ?? DateTime.now(),
    );

    if (date == null) return;

    setState(() {
      _startDate = date;
    });

    await _loadReport();
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _endDate ?? DateTime.now(),
    );

    if (date == null) return;

    setState(() {
      _endDate = date;
    });

    await _loadReport();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _startDate = null;

      _endDate = null;

      _selectedType = 'all';
    });

    await _loadReport();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Todos';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),

      body: _buildBody(),

      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              tooltip: 'Voltar ao topo',
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Icon(Icons.keyboard_arrow_up),
            )
          : null,
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
      onRefresh: _loadReport,

      child: ListView(
        controller: _scrollController,

        padding: const EdgeInsets.all(20),

        children: [
          _buildFilters(),

          const SizedBox(height: 24),

          _buildSummary(),

          const SizedBox(height: 28),

          _buildTransactions(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Filtros',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectStartDate,

                icon: const Icon(Icons.calendar_today),

                label: Text('De: ${_formatDate(_startDate)}'),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectEndDate,

                icon: const Icon(Icons.calendar_today),

                label: Text('Até: ${_formatDate(_endDate)}'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _selectedType,

          decoration: const InputDecoration(
            labelText: 'Tipo de movimentação',
            border: OutlineInputBorder(),
          ),

          items: const [
            DropdownMenuItem(value: 'all', child: Text('Todas')),

            DropdownMenuItem(value: 'earn', child: Text('Pontos recebidos')),

            DropdownMenuItem(value: 'redeem', child: Text('Pontos utilizados')),
          ],

          onChanged: (value) async {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedType = value;
            });

            await _loadReport();
          },
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,

          child: TextButton.icon(
            onPressed: _clearFilters,

            icon: const Icon(Icons.clear),

            label: const Text('Limpar filtros'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Resumo',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 2,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          childAspectRatio: 1.5,

          children: [
            _buildSummaryCard(
              Icons.swap_horiz,
              'Movimentações',
              _totalTransactions.toString(),
            ),

            _buildSummaryCard(
              Icons.stars,
              'Pontos movimentados',
              _totalPoints.toString(),
            ),

            _buildSummaryCard(
              Icons.add_circle_outline,
              'Pontos recebidos',
              _totalEarned.toString(),
            ),

            _buildSummaryCard(
              Icons.remove_circle_outline,
              'Pontos utilizados',
              _totalSpent.toString(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(IconData icon, String title, String value) {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),

            const Spacer(),

            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Movimentações',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        if (_transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),

              child: Text(
                'Nenhuma movimentação encontrada para os filtros selecionados.',
              ),
            ),
          )
        else
          ..._transactions.map(_buildTransaction),
      ],
    );
  }

  String _getTransactionTypeLabel(String? type) {
    switch (type) {
      case 'earn':
        return 'Pontos recebidos';

      case 'redeem':
        return 'Pontos utilizados';

      case 'adjustment':
        return 'Ajuste de pontos';

      case 'expiration':
        return 'Pontos expirados';

      default:
        return 'Movimentação';
    }
  }

  String _getCustomerName(Map<String, dynamic> transaction) {
    final name = transaction['customer_name'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    return 'Cliente';
  }

  Widget _buildTransaction(Map<String, dynamic> transaction) {
    final points = (transaction['points'] ?? 0) as int;

    final type = transaction['type']?.toString();

    final description =
        transaction['description']?.toString() ??
        _getTransactionTypeLabel(type);

    final customerName = _getCustomerName(transaction);

    final createdAt = transaction['created_at']?.toString();

    final isEarn = type == 'earn';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (transaction['customer_avatar_url'] ?? '').toString().isNotEmpty
              ? NetworkImage(transaction['customer_avatar_url'].toString())
              : null,
          child:
              (transaction['customer_avatar_url'] ?? '').toString().isNotEmpty
              ? null
              : Icon(isEarn ? Icons.add : Icons.remove),
        ),

        title: Text(description),

        subtitle: Text(
          '$customerName\n'
          '${_formatTransactionDate(createdAt)}',
        ),

        isThreeLine: true,

        trailing: Text(
          '${points > 0 ? '+' : ''}$points',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEarn ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  String _formatTransactionDate(String? value) {
    if (value == null) {
      return '-';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return '-';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} às '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

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
              onPressed: _loadReport,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
