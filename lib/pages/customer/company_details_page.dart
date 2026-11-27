import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/customer_service.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/company_offer_service.dart';
import '../../services/company_story_service.dart';
import '../../services/promotion_service.dart';
import '../../services/share_service.dart';
import '../../services/publication_view_service.dart';
import '../../services/company_rating_service.dart';
import '../../widgets/company_rating_display.dart';
import '../../widgets/floating_image_card.dart';
import '../../widgets/media_gallery_viewer.dart';

class CompanyDetailsPage extends StatefulWidget {
  const CompanyDetailsPage({super.key, this.company = const {}, this.companyId, this.offerId});

  final Map<String, dynamic> company;
  final String? companyId;
  final String? offerId;

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  final _service = LoyaltyProgramService();
  final _offerService = CompanyOfferService();
  final _customerService = CustomerService();
  final _promotionService = PromotionService();
  final _publicationViewService = PublicationViewService();
  final _ratingService = CompanyRatingService();
  final _storyService = CompanyStoryService();

  List<Map<String, dynamic>> _stories = [];
  Set<String> _viewedStoryIds = <String>{};
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _rewards = [];
  Map<String, int> _pointsByCompany = {};
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = {};
  double? _ratingAverage;
  int _ratingCount = 0;
  int? _myRating;

  static const double _cardWidth = 270;
  static const double _imageSize = 110;
  static const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(12, 12, 12, 8);
  static const int _descriptionMaxChars = 80;

  String get _companyId => widget.company['id']?.toString() ?? widget.companyId ?? '';

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
      List<Map<String, dynamic>> offers = [];
      List<Map<String, dynamic>> rewards = [];
      List<Map<String, dynamic>> stories = [];
      Map<String, int> points = {};
      bool joined = widget.company['joined'] == true;
      try {
        offers = await _offerService.getPublicOffers(companyId: _companyId);
        if (widget.offerId != null) {
          offers.sort((a, b) {
            final aTarget = a['id']?.toString() == widget.offerId ? 1 : 0;
            final bTarget = b['id']?.toString() == widget.offerId ? 1 : 0;
            return bTarget.compareTo(aTarget);
          });
        }
      } catch (_) {}
      try {
        rewards = await _service.getCompanyPromotions(_companyId);
        rewards = rewards
            .where((reward) => ((reward['points_required'] as num?)?.toInt() ?? 0) > 0)
            .toList();
      } catch (_) {}
      try {
        stories = await _storyService.getPublicStories(companyId: _companyId);
      } catch (_) {}
      Set<String> viewed = <String>{};
      try {
        viewed = await _publicationViewService.getViewedStoryIds();
      } catch (_) {}
      try {
        points = await _customerService.getPointsByCompany();
      } catch (_) {}
      // Links compartilhados não trazem extras de navegação, então resolvemos a participação.
      if (!joined) {
        try {
          final myPrograms = await _service.getMyPrograms();
          joined = myPrograms.any((program) => program['company_id']?.toString() == _companyId);
        } catch (_) {}
      }
      double? ratingAverage;
      int ratingCount = 0;
      int? myRating;
      try {
        final rating = (await _ratingService.getStats([_companyId]))[_companyId];
        ratingAverage = (rating?['average_rating'] as num?)?.toDouble();
        ratingCount = (rating?['rating_count'] as num?)?.toInt() ?? 0;
        myRating = (rating?['my_rating'] as num?)?.toInt();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ratingAverage = ratingAverage;
        _ratingCount = ratingCount;
        _myRating = myRating;
        _company = {...widget.company, ...details, 'joined': joined};
        _stories = stories;
        _viewedStoryIds = viewed;
        _offers = offers;
        _rewards = rewards;
        _pointsByCompany = points;
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

  /// Abre o diálogo para avaliar ou, quando [editing] for true, alterar a avaliação já feita.
  Future<void> _rateCompany({bool editing = false}) async {
    if (!editing && (_myRating != null || _company['joined'] != true)) return;
    if (editing && _myRating == null) return;

    int selected = editing ? (_myRating ?? 5) : 5;
    final stars = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing ? 'Editar avaliação' : 'Avaliar empresa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Como foi sua experiência com esta empresa?'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => selected = index + 1),
                    icon: Icon(
                      index < selected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Text('$selected de 5 estrelas'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(editing ? 'Salvar alteração' : 'Enviar avaliação'),
            ),
          ],
        ),
      ),
    );
    if (stars == null) return;
    if (editing && stars == _myRating) return;

    try {
      await _ratingService.submit(_companyId, stars);
      final rating = (await _ratingService.getStats([_companyId]))[_companyId];
      if (!mounted) return;
      setState(() {
        _myRating = stars;
        _ratingAverage = (rating?['average_rating'] as num?)?.toDouble();
        _ratingCount = (rating?['rating_count'] as num?)?.toInt() ?? 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing
                ? 'Sua avaliação foi atualizada. Obrigado!'
                : 'Sua avaliação foi registrada. Obrigado!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---------- Helpers gerais ----------

  String _limitText(String text, [int max = _descriptionMaxChars]) {
    final trimmed = text.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max).trimRight()}…';
  }

  DateTime? _endDate(Map<String, dynamic> item) {
    for (final key in ['ends_at', 'valid_until', 'expires_at']) {
      final value = item[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final date = DateTime.tryParse(value);
      if (date != null) return date.toLocal();
    }
    return null;
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _imageOf(Map<String, dynamic> item) => item['image_url']?.toString() ?? '';

  void _openFullscreen(String url, [List<String>? urls, String? description]) =>
      showFullscreenMediaGallery(context, urls: urls ?? [url], description: description);

  // ---------- Destaques ----------

  List<String> _storyMedia(Map<String, dynamic> story) {
    final raw = story['media_urls'];
    final list = raw is List
        ? raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];
    if (list.isEmpty) {
      final single = story['media_url']?.toString() ?? '';
      if (single.isNotEmpty) list.add(single);
    }
    return list;
  }

  Future<void> _openStory(int index) async {
    final story = _stories[index];
    final media = _storyMedia(story);
    if (media.isEmpty) return;
    await _publicationViewService.recordView(type: 'story', id: story['id'].toString());
    if (mounted) {
      setState(() => _viewedStoryIds.add(story['id'].toString()));
    }
    if (!mounted) return;
    await showFullscreenMediaGallery(
      context,
      urls: media,
      description: story['description']?.toString(),
      title: _company['name']?.toString(),
    );
  }

  Widget _buildStories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Destaques', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final story = _stories[index];
              final media = _storyMedia(story);
              final seen = _viewedStoryIds.contains(story['id']?.toString());
              final avatarUrl = media.isNotEmpty ? media.first : '';
              return InkWell(
                onTap: () => _openStory(index),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: seen ? Colors.grey : Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage:
                                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(Icons.image_outlined)
                                  : null,
                            ),
                            if (media.length > 1)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${media.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _company['name']?.toString() ?? 'Empresa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- Modal de detalhes ----------

  void _showDetailSheet({
    required String image,
    required String title,
    required List<Widget> sections,
    required List<Widget> Function(BuildContext sheetContext) actions,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                if (image.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openFullscreen(image),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        image,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _sheetCompanyLine(),
                const SizedBox(height: 14),
                ...sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: section,
                  ),
                ),
                const SizedBox(height: 6),
                ...actions(sheetContext).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(width: double.infinity, child: action),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetCompanyLine() {
    final logo = _company['logo_url']?.toString() ?? '';
    final name = _company['name']?.toString() ?? 'Empresa';
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 14) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoLine(IconData icon, String text, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }

  void _showOfferDetails(Map<String, dynamic> offer) {
    _publicationViewService.recordView(type: 'offer', id: offer['id'].toString());
    final image = _imageOf(offer);
    final title = offer['title']?.toString() ?? 'Oferta';
    final description = offer['description']?.toString().trim() ?? '';
    final endDate = _endDate(offer);
    _showDetailSheet(
      image: image,
      title: title,
      sections: [
        if (description.isNotEmpty)
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        _infoLine(
          Icons.event_outlined,
          endDate == null
              ? 'Validade não informada'
              : 'Válida até ${_formatDateOnly(endDate)}',
          color: endDate == null ? Colors.grey : Colors.orange,
        ),
      ],
      actions: (sheetContext) => [
        FilledButton.icon(
          onPressed: () => ShareService.shareOffer(
            companyName: _company['name']?.toString() ?? 'Empresa',
            title: title,
            description: offer['description']?.toString(),
            companyLogoUrl: _company['logo_url']?.toString(),
            companyId: _companyId,
            offerId: offer['id']?.toString(),
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartilhar oferta'),
        ),
      ],
    );
  }

  void _showRewardDetails(Map<String, dynamic> reward) {
    final points = (reward['points_required'] as num?)?.toInt() ?? 0;
    final available = _pointsByCompany[_companyId] ?? 0;
    final canRedeem = points > 0 && available >= points;
    final type = reward['type']?.toString();
    final discount = reward['discount_percentage'];
    final gift = reward['gift_description']?.toString().trim() ?? '';
    final rewardText = type == 'discount' && discount != null
        ? '${(discount as num).toStringAsFixed(0)}% de desconto'
        : (gift.isNotEmpty ? gift : 'Brinde');
    final description = reward['description']?.toString().trim() ?? '';
    final endDate = _endDate(reward);
    final title = reward['title']?.toString() ?? 'Recompensa';
    final primary = Theme.of(context).colorScheme.primary;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    _showDetailSheet(
      image: _imageOf(reward),
      title: title,
      sections: [
        Text(
          rewardText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        if (description.isNotEmpty) Text(description, style: bodyStyle),
        _infoLine(Icons.stars_rounded, '$points pontos necessários'),
        if (endDate != null)
          _infoLine(
            Icons.event_outlined,
            'Válido até ${_formatDateOnly(endDate)}',
            color: Colors.orange,
          ),
        _infoLine(
          canRedeem ? Icons.check_circle_outline : Icons.info_outline,
          canRedeem
              ? 'Você já pode resgatar esta recompensa.'
              : 'Faltam ${points - available} pontos nesta empresa.',
          color: canRedeem ? Colors.green : Colors.grey,
        ),
      ],
      actions: (sheetContext) => [
        ElevatedButton(
          onPressed: canRedeem
              ? () {
                  Navigator.pop(sheetContext);
                  _redeem(reward);
                }
              : null,
          child: Text(canRedeem ? 'Resgatar recompensa' : 'Pontos insuficientes'),
        ),
        OutlinedButton.icon(
          onPressed: () => ShareService.sharePromotion(
            companyName: _company['name']?.toString() ?? 'Empresa',
            title: title,
            type: type ?? '',
            discountPercentage: discount?.toString(),
            giftDescription: reward['gift_description']?.toString(),
            description: reward['description']?.toString(),
            companyLogoUrl: _company['logo_url']?.toString(),
            companyId: _companyId,
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartilhar recompensa'),
        ),
      ],
    );
  }

  // ---------- Cabeçalho comum (logo, empresa, compartilhar) ----------

  Widget _cardHeader({required String tooltip, required VoidCallback onShare}) {
    final logo = _company['logo_url']?.toString() ?? '';
    final name = _company['name']?.toString() ?? 'Empresa';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 12) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          onPressed: onShare,
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  // ---------- Ofertas ----------

  List<FloatBlock> _offerBlocks(Map<String, dynamic> offer) {
    final description = _limitText(offer['description']?.toString() ?? '');
    final endDate = _endDate(offer);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    return [
      FloatBlock.widget(
        _cardHeader(
          tooltip: 'Compartilhar oferta',
          onShare: () => ShareService.shareOffer(
            companyName: _company['name']?.toString() ?? 'Empresa',
            title: offer['title']?.toString() ?? 'Oferta',
            description: offer['description']?.toString(),
            companyLogoUrl: _company['logo_url']?.toString(),
            companyId: _companyId,
            offerId: offer['id']?.toString(),
          ),
        ),
        height: 36,
        spacing: 6,
      ),
      FloatBlock.text(
        offer['title']?.toString() ?? 'Oferta',
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      if (description.isNotEmpty)
        FloatBlock.text(
          description,
          bodyStyle.copyWith(fontSize: 13),
          spacing: 6,
          maxLines: 3,
        ),
      FloatBlock.text(
        endDate == null ? 'Validade não informada' : 'Válida até ${_formatDateOnly(endDate)}',
        bodyStyle.copyWith(
          fontSize: 13,
          color: endDate == null ? Colors.grey : Colors.orange,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
      ),
    ];
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final isHighlighted = offer['id']?.toString() == widget.offerId;
    final primary = Theme.of(context).colorScheme.primary;
    final image = _imageOf(offer);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHighlighted ? BorderSide(color: primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOfferDetails(offer),
        child: FloatingImageCard(
          padding: _cardPadding,
          imageUrl: image.isEmpty ? null : image,
          imageSize: _imageSize,
          blocks: _offerBlocks(offer),
          mediaCount: offer['media_urls'] is List && (offer['media_urls'] as List).length > 1
              ? (offer['media_urls'] as List).length
              : 1,
          onImageTap: image.isEmpty
              ? null
              : () async {
                  await _publicationViewService.recordView(
                    type: 'offer',
                    id: offer['id'].toString(),
                  );
                  if (!mounted) return;
                  _openFullscreen(
                    image,
                    List<String>.from(
                      offer['media_urls'] is List ? offer['media_urls'] as List : [image],
                    ),
                    offer['description']?.toString(),
                  );
                },
        ),
      ),
    );
  }

  Widget _buildOffersSection() {
    final visible = _offers.take(10).toList();
    final heights = visible
        .map(
          (offer) => FloatingImageCard.measureHeight(
            context,
            blocks: _offerBlocks(offer),
            imageUrl: _imageOf(offer),
            imageSize: _imageSize,
            gap: 12,
            width: _cardWidth,
            padding: _cardPadding,
          ),
        )
        .toList();
    final listHeight = heights.fold<double>(0, (acc, h) => h > acc ? h : acc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Ofertas disponíveis', style: Theme.of(context).textTheme.titleLarge),
        if (widget.offerId != null) ...[
          const SizedBox(height: 6),
          Text(
            _offers.any((offer) => offer['id']?.toString() == widget.offerId)
                ? 'Oferta compartilhada em destaque'
                : 'Esta oferta não está mais ativa ou disponível.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              height: heights[index],
              child: _offerCard(visible[index]),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Recompensas ----------

  Future<void> _redeem(Map<String, dynamic> reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resgatar recompensa?'),
        content: Text(
          'Você vai utilizar ${reward['points_required']} pontos para resgatar:\n\n${reward['title']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _promotionService.redeemPromotion(reward['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recompensa resgatada! Novo saldo: ${result['new_balance']} pontos.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<FloatBlock> _rewardBlocks(Map<String, dynamic> reward) {
    final points = (reward['points_required'] as num?)?.toInt() ?? 0;
    final available = _pointsByCompany[_companyId] ?? 0;
    final canRedeem = points > 0 && available >= points;
    final type = reward['type']?.toString();
    final discount = reward['discount_percentage'];
    final gift = reward['gift_description']?.toString().trim() ?? '';
    final rewardText = type == 'discount' && discount != null
        ? '${(discount as num).toStringAsFixed(0)}% de desconto'
        : (gift.isNotEmpty ? gift : 'Brinde');
    final description = _limitText(reward['description']?.toString() ?? '');
    final endDate = _endDate(reward);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;
    return [
      FloatBlock.widget(
        _cardHeader(
          tooltip: 'Compartilhar recompensa',
          onShare: () => ShareService.sharePromotion(
            companyName: _company['name']?.toString() ?? 'Empresa',
            title: reward['title']?.toString() ?? 'Recompensa',
            type: type ?? '',
            discountPercentage: discount?.toString(),
            giftDescription: reward['gift_description']?.toString(),
            description: reward['description']?.toString(),
            companyLogoUrl: _company['logo_url']?.toString(),
            companyId: _companyId,
          ),
        ),
        height: 36,
        spacing: 6,
      ),
      FloatBlock.text(
        reward['title']?.toString() ?? 'Recompensa',
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      FloatBlock.text(
        rewardText,
        bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
        spacing: 6,
        maxLines: 1,
        fullWidth: true,
      ),
      if (description.isNotEmpty)
        FloatBlock.text(
          description,
          bodyStyle.copyWith(fontSize: 13),
          spacing: 6,
          maxLines: 3,
        ),
      if (endDate != null)
        FloatBlock.text(
          'Válido até ${_formatDateOnly(endDate)}',
          bodyStyle.copyWith(
            fontSize: 13,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
          spacing: 6,
          maxLines: 1,
        ),
      FloatBlock.text(
        canRedeem
            ? 'Você já pode resgatar esta recompensa.'
            : 'Faltam ${points - available} pontos nesta empresa.',
        bodyStyle.copyWith(fontSize: 13, color: canRedeem ? Colors.green : Colors.grey),
        spacing: 8,
        maxLines: 2,
      ),
      FloatBlock.widget(_rewardActions(reward, canRedeem, points), height: 40, topGap: 10),
    ];
  }

  Widget _rewardActions(Map<String, dynamic> reward, bool canRedeem, int points) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: canRedeem
                ? Colors.green.withValues(alpha: .12)
                : Colors.grey.withValues(alpha: .12),
          ),
          child: Text(
            '$points pts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: canRedeem ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: canRedeem ? () => _redeem(reward) : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(canRedeem ? 'Resgatar recompensa' : 'Pontos insuficientes'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rewardCard(Map<String, dynamic> reward) {
    final image = _imageOf(reward);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRewardDetails(reward),
        child: FloatingImageCard(
          padding: _cardPadding,
          imageUrl: image.isEmpty ? null : image,
          imageSize: _imageSize,
          blocks: _rewardBlocks(reward),
          mediaCount: reward['media_urls'] is List && (reward['media_urls'] as List).length > 1
              ? (reward['media_urls'] as List).length
              : 1,
          onImageTap: image.isEmpty
              ? null
              : () => _openFullscreen(
                    image,
                    List<String>.from(
                      reward['media_urls'] is List ? reward['media_urls'] as List : [image],
                    ),
                    reward['description']?.toString(),
                  ),
        ),
      ),
    );
  }

  Widget _buildRewardsSection() {
    final visible = _rewards.take(10).toList();
    final heights = visible
        .map(
          (reward) => FloatingImageCard.measureHeight(
            context,
            blocks: _rewardBlocks(reward),
            imageUrl: _imageOf(reward),
            imageSize: _imageSize,
            gap: 12,
            width: _cardWidth,
            padding: _cardPadding,
          ),
        )
        .toList();
    final listHeight = heights.fold<double>(0, (acc, h) => h > acc ? h : acc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Recompensas de fidelidade', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              height: heights[index],
              child: _rewardCard(visible[index]),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Contato e redes ----------

  String get _phoneDigits => (_company['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

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

  String _socialUsername(String key) =>
      (_company[key] ?? '').toString().trim().replaceFirst(RegExp(r'^@+'), '');

  Future<void> _openSocial(String platform, String username) async {
    if (username.isEmpty) return;
    final uri = Uri.parse(platform == 'instagram'
        ? 'https://www.instagram.com/$username/'
        : 'https://www.tiktok.com/@$username');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o $platform.')),
      );
    }
  }

  String get _location {
    final city = (_company['city'] ?? '').toString().trim();
    final state = (_company['state'] ?? '').toString().trim();
    return [city, state].where((part) => part.isNotEmpty).join(' - ');
  }

  /// Linha de avaliação do cliente: nota atual e botão para avaliar ou editar.
  Widget _myRatingRow() {
    if (_myRating == null) {
      return TextButton.icon(
        onPressed: () => _rateCompany(),
        icon: const Icon(Icons.star_outline_rounded),
        label: const Text('Avaliar empresa'),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sua avaliação: $_myRating/5 estrelas',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () => _rateCompany(editing: true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar avaliação'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_company['name'] ?? 'Empresa').toString();
    final description = (_company['description'] ?? '').toString().trim();
    final address = (_company['address'] ?? '').toString().trim();
    final phone = (_company['phone'] ?? '').toString().trim();
    final logoUrl = (_company['logo_url'] ?? '').toString().trim();
    final instagram = _socialUsername('instagram_username');
    final tiktok = _socialUsername('tiktok_username');
    final joined = _company['joined'] == true;
    final fullAddress = [
      if (address.isNotEmpty) address,
      if (_location.isNotEmpty) _location,
    ].join('\n');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre a empresa'),
        actions: [
          IconButton(
            tooltip: 'Ir para Home do Plim',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
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
                        GestureDetector(
                          onTap: logoUrl.isEmpty ? null : () => _openFullscreen(logoUrl),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                            child: logoUrl.isEmpty
                                ? const Icon(Icons.storefront_outlined, size: 36)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CompanyRatingDisplay(average: _ratingAverage, count: _ratingCount),
                        if (joined || _myRating != null) ...[
                          const SizedBox(height: 6),
                          _myRatingRow(),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => ShareService.shareCompanyClub(
                            companyName: name,
                            companyLogoUrl: logoUrl,
                            companyId: _companyId,
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar empresa'),
                        ),
                        if (_location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 17),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(_location, textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if ((_company['category']?.toString() ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Chip(
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      label: Text(_company['category'].toString()),
                    ),
                  ),
                ],
                if (_stories.isNotEmpty) _buildStories(),
                if (_offers.isNotEmpty) _buildOffersSection(),
                if (_offers.isEmpty && widget.offerId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Esta oferta não está mais ativa ou disponível.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_rewards.isNotEmpty) _buildRewardsSection(),
                const SizedBox(height: 18),
                Text('Sobre a empresa', style: Theme.of(context).textTheme.titleLarge),
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
                Text('Contato e endereço', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('WhatsApp'),
                        subtitle: Text(phone.isNotEmpty ? phone : 'Não informado'),
                        trailing: phone.isNotEmpty
                            ? const Icon(Icons.open_in_new, size: 18)
                            : null,
                        onTap: phone.isNotEmpty ? _openWhatsApp : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Endereço'),
                        subtitle: Text(fullAddress.isNotEmpty ? fullAddress : 'Não informado'),
                        isThreeLine: address.isNotEmpty && _location.isNotEmpty,
                      ),
                    ],
                  ),
                ),
                if (instagram.isNotEmpty || tiktok.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Redes sociais', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        if (instagram.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.camera_alt_outlined),
                            title: const Text('Instagram'),
                            subtitle: Text('@$instagram'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _openSocial('instagram', instagram),
                          ),
                        if (instagram.isNotEmpty && tiktok.isNotEmpty) const Divider(height: 1),
                        if (tiktok.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.music_note_outlined),
                            title: const Text('TikTok'),
                            subtitle: Text('@$tiktok'),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _openSocial('tiktok', tiktok),
                          ),
                      ],
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Conversar pelo WhatsApp'),
                  ),
                ],
                const SizedBox(height: 10),
                if (joined)
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
                  )
                else
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await _service.joinProgram(_companyId);
                        if (!mounted) return;
                        setState(() => _company['joined'] = true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Agora você participa da fidelidade de $name!')),
                        );
                        await context.push('/customer/loyalty-program', extra: {..._company, 'joined': true});
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Participar da fidelidade'),
                  ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}