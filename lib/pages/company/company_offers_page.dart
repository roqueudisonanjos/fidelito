import 'package:flutter/material.dart';
import '../../services/company_offer_service.dart';
import '../../services/company_story_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/publication_view_service.dart';
import '../../widgets/media_gallery_viewer.dart';
import '../../widgets/company/company_bottom_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/share_service.dart';

class CompanyOffersPage extends StatefulWidget {
  const CompanyOffersPage({super.key});

  @override
  State<CompanyOffersPage> createState() => _CompanyOffersPageState();
}

class _CompanyOffersPageState extends State<CompanyOffersPage> {
  final _service = CompanyOfferService();
  final _storyService = CompanyStoryService();
  final _imageUploadService = ImageUploadService();
  final _viewService = PublicationViewService();

  Map<String, int> _viewCounts = {};
  String? _companyId;
  String? _companyName;
  String? _companyLogoUrl;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _stories = [];
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

      Map<String, dynamic>? companyRow;
      try {
        companyRow = await Supabase.instance.client
            .from('companies')
            .select('name, logo_url')
            .eq('id', id)
            .maybeSingle();
      } catch (_) {
        // Sem nome/logo, o compartilhamento ainda funciona com valores padrão.
      }

      final offers = await _service.getMyOffers(id);
      final stories = await _storyService.getMyStories(id);

      Map<String, int> viewCounts = {};
      try {
        viewCounts = await _viewService.getCompanyCounts(id);
      } catch (_) {
        // A tela de divulgação continua acessível mesmo se a métrica estiver indisponível.
      }

      if (!mounted) return;
      setState(() {
        _companyName = companyRow?['name']?.toString();
        _companyLogoUrl = companyRow?['logo_url']?.toString();
        _companyId = id;
        _offers = offers;
        _stories = stories;
        _viewCounts = viewCounts;
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
    final mediaUrls = List<String>.from(offer?['media_urls'] is List ? offer!['media_urls'] as List : (imageController.text.trim().isEmpty ? [] : [imageController.text.trim()]));
    bool uploadingMedia = false;
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: uploadingMedia || mediaUrls.length >= 5 ? null : () async {
                          updateDialog(() => uploadingMedia = true);
                          try {
                            final uploaded = await _imageUploadService.pickAndUploadMultiple(folder: 'offers', filePrefix: 'offer', maxCount: 5 - mediaUrls.length);
                            if (uploaded.isNotEmpty) {
                              if (mediaUrls.length + uploaded.length > 5) {
                                throw Exception('Cada oferta pode ter no máximo 5 mídias.');
                              }
                              updateDialog(() { mediaUrls.addAll(uploaded); imageController.clear(); });
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) updateDialog(() => uploadingMedia = false);
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(uploadingMedia ? 'Enviando mídias...' : 'Adicionar mídias (${mediaUrls.length}/5)'),
                      ),
                    ),
                    if (mediaUrls.isNotEmpty)
                      SizedBox(
                        height: 76,
                        child: ListView(scrollDirection: Axis.horizontal, children: [
                          for (final url in mediaUrls)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 68, height: 68, child: Icon(Icons.perm_media))),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: InkWell(
                                    onTap: () => updateDialog(() {
                                      mediaUrls.remove(url);
                                      if (mediaUrls.isEmpty) {
                                        imageController.clear();
                                      } else {
                                        imageController.text = mediaUrls.first;
                                      }
                                    }),
                                    child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
                                  ),
                                ),
                              ]),
                            ),
                        ]),
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
                    mediaUrls: mediaUrls,
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

  Future<void> _chooseNewPublication() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Criar oferta'),
            onTap: () => Navigator.pop(context, 'offer'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Criar destaque'),
            onTap: () => Navigator.pop(context, 'story'),
          ),
        ]),
      ),
    );

    if (choice == 'offer') await _edit(null);
    if (choice == 'story') await _createStory();
  }

  Future<void> _createStory([Map<String, dynamic>? story]) async {
    DateTime expiresAt = _asDate(story?['expires_at'], DateTime.now().add(const Duration(days: 1)));
    final descriptionController = TextEditingController(text: story?['description']?.toString() ?? '');
    final mediaUrls = List<String>.from(story?['media_urls'] is List ? story!['media_urls'] as List : (story?['media_url'] == null ? [] : [story!['media_url'].toString()]));
    bool uploading = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(story == null ? 'Novo destaque' : 'Editar destaque'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton.icon(
                  onPressed: uploading || mediaUrls.length >= 5
                      ? null
                      : () async {
                          setDialogState(() => uploading = true);
                          try {
                            final uploaded = await _imageUploadService.pickAndUploadMultiple(
                              folder: 'stories',
                              filePrefix: 'story',
                              maxCount: 5 - mediaUrls.length,
                            );
                            if (uploaded.isNotEmpty) {
                              if (mediaUrls.length + uploaded.length > 5) {
                                throw Exception('Cada destaque pode ter no máximo 5 mídias.');
                              }
                              setDialogState(() => mediaUrls.addAll(uploaded));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Falha ao enviar mídia: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => uploading = false);
                          }
                        },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(uploading ? 'Enviando...' : 'Adicionar mídias (${mediaUrls.length}/5)'),
                ),
                if (mediaUrls.isNotEmpty)
                  SizedBox(
                    height: 76,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final url in mediaUrls)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(url, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 68, height: 68, child: Icon(Icons.perm_media))),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => setDialogState(() => mediaUrls.remove(url)),
                                child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Texto do destaque (opcional)'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Não exibir depois de'),
                  subtitle: Text('${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: expiresAt.isBefore(DateTime.now()) ? DateTime.now() : expiresAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                      });
                    }
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: mediaUrls.isEmpty || uploading ? null : () => Navigator.pop(dialogContext, true),
              child: Text(story == null ? 'Publicar destaque' : 'Salvar alterações'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || mediaUrls.isEmpty || _companyId == null) {
      descriptionController.dispose();
      return;
    }

    try {
      await _storyService.createStory(
        id: story?['id']?.toString(),
        companyId: _companyId!,
        mediaUrls: mediaUrls,
        description: descriptionController.text,
        expiresAt: expiresAt,
      );
      descriptionController.dispose();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(story == null ? 'Destaque publicado.' : 'Destaque atualizado.')),
        );
      }
    } catch (e) {
      descriptionController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível publicar: $e')),
        );
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: const CompanyBottomNavigation(selectedIndex: 4),
        floatingActionButton: _loading || _companyId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _chooseNewPublication,
                icon: const Icon(Icons.add),
                label: const Text('Nova divulgação'),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : Column(children: [
                    const Material(
                      child: TabBar(tabs: [
                        Tab(text: 'Ofertas', icon: Icon(Icons.local_offer_outlined)),
                        Tab(text: 'Destaques', icon: Icon(Icons.auto_awesome_outlined)),
                      ]),
                    ),
                    Expanded(
                      child: TabBarView(children: [
                        _buildOffersTab(),
                        _buildStoriesTab(),
                      ]),
                    ),
                  ]),
      ),
    );
  }

  Widget _buildOffersTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _offers.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 90),
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
                final rawMedia = offer['media_urls'];
                final mediaUrls = rawMedia is List
                    ? rawMedia.map((value) => value.toString()).where((value) => value.trim().isNotEmpty).toList()
                    : <String>[];
                if (mediaUrls.isEmpty && imageUrl.isNotEmpty) mediaUrls.add(imageUrl);
                if (mediaUrls.isNotEmpty && imageUrl.isNotEmpty && !mediaUrls.contains(imageUrl)) mediaUrls.insert(0, imageUrl);
                final views = _viewCounts['offer:${offer['id']}'] ?? 0;
                final validUntil = DateTime.tryParse(offer['ends_at']?.toString() ?? '')?.toLocal();
                final validUntilLabel = validUntil == null
                    ? 'Validade não informada'
                    : 'Valida até ${validUntil.day.toString().padLeft(2, '0')}/${validUntil.month.toString().padLeft(2, '0')}/${validUntil.year}';
                final active = status == 'Ativa';
                final colors = Theme.of(context).colorScheme;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (mediaUrls.isNotEmpty)
                      InkWell(
                        onTap: () => showFullscreenMediaGallery(
                          context,
                          urls: mediaUrls,
                          title: offer['title']?.toString(),
                          description: offer['description']?.toString(),
                        ),
                        child: Stack(alignment: Alignment.bottomRight, children: [
                          Image.network(
                            mediaUrls.first,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(height: 150, child: Center(child: Icon(Icons.image_not_supported_outlined))),
                          ),
                          if (mediaUrls.length > 1)
                            Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                              child: Text('${mediaUrls.length} mídias', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                        ]),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              offer['title']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                          if (active)
                            IconButton(
                              tooltip: 'Compartilhar oferta',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => ShareService.shareOffer(
                                companyName: _companyName ?? 'Empresa',
                                title: offer['title']?.toString() ?? 'Oferta',
                                description: offer['description']?.toString(),
                                companyLogoUrl: _companyLogoUrl,
                                companyId: _companyId,
                                offerId: offer['id']?.toString(),
                              ),
                              icon: const Icon(Icons.share_outlined),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') await _edit(offer);
                              if (value == 'delete') await _delete(offer);
                              if (value == 'toggle') {
                                try {
                                  await _service.toggleActive(offer['id'].toString(), offer['active'] != true, companyId: _companyId!);
                                  await _load();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'toggle', child: Text(offer['active'] == true ? 'Desativar' : 'Ativar')),
                              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: active ? colors.primaryContainer : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.visibility_outlined, size: 15, color: colors.onSecondaryContainer),
                                const SizedBox(width: 5),
                                Text(
                                  '$views visualizações',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSecondaryContainer),
                                ),
                              ]),
                            ),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.event_outlined, size: 16, color: colors.onSurfaceVariant),
                              const SizedBox(width: 5),
                              Text(validUntilLabel, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                            ]),
                          ],
                        ),
                        if ((offer['description']?.toString() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(offer['description'].toString()),
                        ],
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildStoriesTab() {
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: _stories.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 90),
                Icon(Icons.auto_awesome_outlined, size: 48),
                SizedBox(height: 12),
                Text('Você ainda não publicou destaques.', textAlign: TextAlign.center),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: _stories.map((story) {
                final expires = DateTime.tryParse(story['expires_at']?.toString() ?? '')?.toLocal();
                final active = story['active'] == true && (expires == null || expires.isAfter(now));
                final storyMedia = List<String>.from(story['media_urls'] is List ? story['media_urls'] as List : [story['media_url']]);
                final views = _viewCounts['story:${story['id']}'] ?? 0;
                final expiresLabel = expires == null
                    ? 'Sem validade definida'
                    : 'Válido até ${expires.day.toString().padLeft(2, '0')}/${expires.month.toString().padLeft(2, '0')}/${expires.year}';
                final colorScheme = Theme.of(context).colorScheme;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                story['media_url']?.toString() ?? '',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 64,
                                  height: 64,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.auto_awesome_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (story['description']?.toString().trim().isNotEmpty ?? false)
                                        ? story['description'].toString().trim()
                                        : 'Destaque',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      active ? 'Ativo' : 'Inativo',
                                      style: TextStyle(
                                        color: active
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Ações do destaque',
                              onSelected: (value) async {
                                if (value == 'preview') {
                                  await showFullscreenMediaGallery(
                                    context,
                                    urls: storyMedia,
                                    description: story['description']?.toString(),
                                    title: 'Prévia do destaque',
                                  );
                                } else if (value == 'edit') {
                                  await _createStory(story);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'preview', child: Text('Visualizar como cliente')),
                                PopupMenuItem(value: 'edit', child: Text('Editar destaque')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_outlined, size: 17, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 5),
                                Text(expiresLabel, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_outlined, size: 16, color: colorScheme.onSecondaryContainer),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$views visualizações',
                                    style: TextStyle(
                                      color: colorScheme.onSecondaryContainer,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Exibir', style: TextStyle(fontSize: 12)),
                              Switch.adaptive(
                                value: story['active'] == true,
                                onChanged: (value) async {
                                  await _storyService.setActive(story['id'].toString(), _companyId!, value);
                                  await _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}