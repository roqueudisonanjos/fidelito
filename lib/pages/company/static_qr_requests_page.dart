import 'package:flutter/material.dart';
import '../../services/static_qr_request_service.dart';


class StaticQrRequestsPage extends StatefulWidget {
  const StaticQrRequestsPage({super.key});
  @override
  State<StaticQrRequestsPage> createState() => _StaticQrRequestsPageState();
}


class _StaticQrRequestsPageState extends State<StaticQrRequestsPage> {
  final StaticQrRequestService _service = StaticQrRequestService();
  bool _loading = true;
  String? _error;
  String? _processingId;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.getPendingRequests();
      if (!mounted) return;
      setState(() { _requests = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _decide(Map<String, dynamic> request, {required bool approve}) async {
    final id = request['id']?.toString();
    if (id == null || _processingId != null) return;
    setState(() => _processingId = id);
    try {
      if (approve) {
        await _service.approve(id);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rejeitar solicitação?'),
            content: Text('A solicitação de ${request['points']} pontos de ${request['customer_name']} será rejeitada e nenhum ponto será creditado.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rejeitar')),
            ],
          ),
        );
        if (confirmed != true) { if (mounted) setState(() => _processingId = null); return; }
        await _service.reject(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Pontos aprovados e creditados ao cliente.' : 'Solicitação rejeitada.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível processar: $e')));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações de pontos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _requests.isEmpty
                      ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 180), Icon(Icons.notifications_none, size: 56), SizedBox(height: 12), Center(child: Text('Nenhuma solicitação pendente.'))])
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            final id = request['id']?.toString() ?? '';
                            final busy = _processingId == id;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [const Icon(Icons.person_outline), const SizedBox(width: 8), Expanded(child: Text(request['customer_name']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))]),
                                  const SizedBox(height: 10),
                                  Text('${request['points']} pontos solicitados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                  const SizedBox(height: 4),
                                  Text('QR Code permanente', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                  Text(_date(request['created_at']), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                  const SizedBox(height: 14),
                                  Row(children: [
                                    Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _decide(request, approve: false), icon: const Icon(Icons.close), label: const Text('Rejeitar'))),
                                    const SizedBox(width: 10),
                                    Expanded(child: FilledButton.icon(onPressed: busy ? null : () => _decide(request, approve: true), icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: const Text('Aprovar'))),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
