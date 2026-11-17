import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/loyalty_program_service.dart';

class CompanyDetailsPage extends StatefulWidget {
  const CompanyDetailsPage({super.key, required this.company});

  final Map<String, dynamic> company;

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  final _service = LoyaltyProgramService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = {};

  String get _companyId => widget.company['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _error = 'Não foi possível identificar esta empresa.';
        _loading = false;
      });
      return;
    }

    try {
      final details = await _service.getCompanyDetails(_companyId);
      if (!mounted) return;
      setState(() {
        _company = {...widget.company, ...details};
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

  String get _phoneDigits =>
      (_company['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _openWhatsApp() async {
    var number = _phoneDigits;
    if (number.isEmpty) return;
    if (!number.startsWith('55')) number = '55$number';

    final uri = Uri.parse('https://wa.me/$number');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  String get _location {
    final city = (_company['city'] ?? '').toString().trim();
    final state = (_company['state'] ?? '').toString().trim();
    return [city, state].where((part) => part.isNotEmpty).join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final name = (_company['name'] ?? 'Empresa').toString();
    final description = (_company['description'] ?? '').toString().trim();
    final address = (_company['address'] ?? '').toString().trim();
    final phone = (_company['phone'] ?? '').toString().trim();
    final logoUrl = (_company['logo_url'] ?? '').toString().trim();
    final joined = _company['joined'] == true;
    final fullAddress = [
      if (address.isNotEmpty) address,
      if (_location.isNotEmpty) _location,
    ].join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre a empresa')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          backgroundImage: logoUrl.isNotEmpty
                              ? NetworkImage(logoUrl)
                              : null,
                          child: logoUrl.isEmpty
                              ? const Icon(Icons.storefront_outlined, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 17),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _location,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sobre a empresa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      description.isNotEmpty
                          ? description
                          : 'Esta empresa ainda não adicionou uma descrição.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Contato e endereço',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('WhatsApp'),
                        subtitle: Text(
                          phone.isNotEmpty ? phone : 'Não informado',
                        ),
                        trailing: phone.isNotEmpty
                            ? const Icon(Icons.open_in_new, size: 18)
                            : null,
                        onTap: phone.isNotEmpty ? _openWhatsApp : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Endereço'),
                        subtitle: Text(
                          fullAddress.isNotEmpty
                              ? fullAddress
                              : 'Não informado',
                        ),
                        isThreeLine: address.isNotEmpty && _location.isNotEmpty,
                      ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Conversar pelo WhatsApp'),
                  ),
                ],
                if (joined) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final left = await context.push<bool>(
                        '/customer/loyalty-program',
                        extra: _company,
                      );
                      if (!context.mounted) return;
                      if (left == true) context.pop(true);
                    },
                    icon: const Icon(Icons.loyalty_outlined),
                    label: const Text('Ver minha fidelidade'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
