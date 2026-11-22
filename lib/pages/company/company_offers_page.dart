import 'package:flutter/material.dart';

import '../../widgets/company/company_app_bar_actions.dart';

import '../../services/company_offer_service.dart';
import '../../widgets/company/company_bottom_navigation.dart';

class CompanyOffersPage extends StatefulWidget {
  const CompanyOffersPage({super.key});

  @override
  State<CompanyOffersPage> createState() => _CompanyOffersPageState();
}

class _CompanyOffersPageState extends State<CompanyOffersPage> {
  final _service = CompanyOfferService();
  String? _companyId;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await _service.getOwnedCompanyId();
      final offers = await _service.getMyOffers(id);
      if (!mounted) return;
      setState(() {
        _companyId = id;
        _offers = offers;
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


  DateTime _asDate(dynamic raw, DateTime fallback) {
    return DateTime.tryParse(raw?.toString() ?? '')?.toLocal() ?? fallback;
  }


  Future<void> _edit(Map<String, dynamic>? offer) async {
    final titleController = TextEditingController(text: offer?['title']?.toString() ?? '');
    final descriptionController = TextEditingController(text: offer?['description']?.toString() ?? '');
    final imageController = TextEditingController(text: offer?['image_url']?.toString() ?? '');
    DateTime start = _asDate(offer?['starts_at'], DateTime.now());
    DateTime end = _asDate(offer?['ends_at'], DateTime.now().add(const Duration(days: 7)));
    bool active = offer?['active'] != false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(offer == null ? 'Criar oferta' : 'Editar oferta'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título *'),
                      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Informe o título' : null,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    TextFormField(
                      controller: imageController,
                      decoration: const InputDecoration(labelText: 'URL da imagem (opcional)'),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final uri = Uri.tryParse(text);
                        if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
                          return 'Informe uma URL válida (http ou https).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Início'),
                      subtitle: Text('${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}'),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: start,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          updateDialog(() => start = DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Validade'),
                      subtitle: Text('${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}'),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final initial = end.isBefore(start) ? start : end;
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: initial,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          updateDialog(() => end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Oferta ativa'),
                      value: active,
                      onChanged: (value) => updateDialog(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (!end.isAfter(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A validade precisa ser posterior à data de início.')),
                  );
                  return;
                }
                try {
                  await _service.saveOffer(
                    id: offer?['id']?.toString(),
                    companyId: _companyId!,
                    title: titleController.text,
                    description: descriptionController.text,
                    imageUrl: imageController.text,
                    start: start,
                    end: end,
                    active: active,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    imageController.dispose();
  }


  Future<void> _delete(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir oferta?'),
        content: Text('“${offer['title']}” será removida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteOffer(offer['id'].toString(), companyId: _companyId!);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }


  String _status(Map<String, dynamic> offer) {
    if (offer['active'] != true) return 'Inativa';
    final end = DateTime.tryParse(offer['ends_at']?.toString() ?? '')?.toLocal();
    if (end != null && end.isBefore(DateTime.now())) return 'Expirada';
    final start = DateTime.tryParse(offer['starts_at']?.toString() ?? '')?.toLocal();
    if (start != null && start.isAfter(DateTime.now())) return 'Agendada';
    return 'Ativa';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas ofertas'),
        actions: [CompanyAppBarActions(onRefresh: _load, refreshEnabled: !_loading)],
      ),
      bottomNavigationBar: const CompanyBottomNavigation(selectedIndex: 4),
      floatingActionButton: _loading || _companyId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('Nova oferta'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _offers.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 100),
                            Icon(Icons.local_offer_outlined, size: 48),
                            SizedBox(height: 12),
                            Text('Você ainda não criou ofertas.', textAlign: TextAlign.center),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: _offers.map((offer) {
                            final status = _status(offer);
                            final imageUrl = offer['image_url']?.toString() ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    Image.network(
                                      imageUrl,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                    ),
                                  ListTile(
                                    title: Text(offer['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(status),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') await _edit(offer);
                                        if (value == 'delete') await _delete(offer);
                                        if (value == 'toggle') {
                                          try {
                                            await _service.toggleActive(offer['id'].toString(), offer['active'] != true, companyId: _companyId!);
                                            await _load();
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        PopupMenuItem(value: 'toggle', child: Text(offer['active'] == true ? 'Desativar' : 'Ativar')),
                                        const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                      ],
                                    ),
                                  ),
                                  if ((offer['description']?.toString() ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Text(offer['description'].toString()),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
    );
  }
}
