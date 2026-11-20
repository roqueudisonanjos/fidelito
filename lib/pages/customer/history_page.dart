import 'package:flutter/material.dart';

import '../../models/loyalty_transaction.dart';
import '../../services/customer_service.dart';
import '../../services/loyalty_program_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.companyId, this.companyName});

  final String? companyId;
  final String? companyName;


  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final CustomerService _service = CustomerService();
  final LoyaltyProgramService _loyaltyService = LoyaltyProgramService();

  bool _loading = true;

  String? _error;

  List<LoyaltyTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<LoyaltyTransaction> transactions;
      if (widget.companyId == null) {
        transactions = await _service.getTransactions();
      } else {
        final companyRows = await _loyaltyService.getCompanyTransactions(widget.companyId!);
        transactions = companyRows
            .map((row) => LoyaltyTransaction.fromMap(row))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
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
      appBar: AppBar(
        title: Text(
          widget.companyName == null || widget.companyName!.trim().isEmpty
              ? 'Histórico de pontos'
              : 'Histórico • ${widget.companyName}',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
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
                      onPressed: _loadHistory,
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

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: _transactions.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                return _buildTransaction(_transactions[index]);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 180),
        Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Nenhuma movimentação ainda.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Seu histórico aparecerá aqui.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransaction(LoyaltyTransaction transaction) {
    final isPositive = transaction.points > 0;

    final icon = isPositive ? Icons.add_circle : Icons.remove_circle;

    final color = isPositive ? Colors.green : Colors.red;

    final prefix = isPositive ? '+' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          transaction.description ?? 'Movimentação de pontos',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_formatDate(transaction.createdAt)),
        trailing: Text(
          '$prefix${transaction.points}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às '
        '$hour:$minute';
  }
}
