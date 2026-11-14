import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/loyalty_program_service.dart';

class MyLoyaltyProgramsPage extends StatefulWidget {
  const MyLoyaltyProgramsPage({super.key});
  @override
  State<MyLoyaltyProgramsPage> createState() => _MyLoyaltyProgramsPageState();
}

class _MyLoyaltyProgramsPageState extends State<MyLoyaltyProgramsPage> {
  final _service = LoyaltyProgramService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _programs = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _service.getMyPrograms();
      if (!mounted) return;
      setState(() { _programs = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minhas fidelidades')),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Text(_error!))
      : _programs.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.loyalty_outlined, size: 56), const SizedBox(height: 12),
            const Text('Você ainda não participa de nenhum programa de fidelidade.', textAlign: TextAlign.center),
            const SizedBox(height: 12), FilledButton.icon(onPressed: () => context.push('/customer/explore'), icon: const Icon(Icons.explore_outlined), label: const Text('Explorar empresas')),
          ])))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: _programs.length,
            itemBuilder: (context, index) {
              final row = _programs[index];
              final company = Map<String, dynamic>.from(row['companies'] as Map);
              final location = [company['city'], company['state']].where((v) => v != null && v.toString().isNotEmpty).join(' - ');
              return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
                title: Text(company['name']?.toString() ?? 'Empresa', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${row['points'] ?? 0} pontos${location.isEmpty ? '' : '\n$location'}')),
                isThreeLine: location.isNotEmpty,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/customer/loyalty-program', extra: company),
              ));
            },
          )),
  );
}
