import 'package:flutter/material.dart';

import '../../models/loyalty_transaction.dart';
import '../../services/customer_service.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final CustomerService _service = CustomerService();

  bool _loading = true;

  String? _error;

  List<LoyaltyTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();

    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final transactions = await _service.getAllTransactions();

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
      appBar: AppBar(title: const Text('Histórico de pontos')),

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
      onRefresh: _loadTransactions,

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
                'Nenhuma movimentação encontrada.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
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
                  onPressed: _loadTransactions,

                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransaction(LoyaltyTransaction transaction) {
    final isPositive = transaction.points > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),

      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPositive
              ? Colors.green.withValues(alpha: .12)
              : Colors.red.withValues(alpha: .12),

          child: Icon(
            isPositive ? Icons.add : Icons.remove,

            color: isPositive ? Colors.green : Colors.red,
          ),
        ),

        title: Text(transaction.description ?? 'Movimentação de pontos'),

        subtitle: Text(_formatDate(transaction.createdAt)),

        trailing: Text(
          '${isPositive ? '+' : ''}'
          '${transaction.points}',

          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,

            color: isPositive ? Colors.green : Colors.red,
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
