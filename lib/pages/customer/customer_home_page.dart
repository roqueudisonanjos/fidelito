import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/loyalty_transaction.dart';
import '../../models/promotion.dart';
import '../../services/auth_service.dart';
import '../../services/customer_service.dart';
import '../../services/promotion_service.dart';
import '../../services/support_service.dart';
import '../../services/share_service.dart';
import '../../services/notification_service.dart';
import '../../services/company_offer_service.dart';
import '../../services/company_story_service.dart';
import '../../services/publication_view_service.dart';
import '../../services/loyalty_program_service.dart';
import '../../services/company_rating_service.dart';
import '../../widgets/company_rating_display.dart';
import '../../services/qr_service.dart';
import '../../widgets/help_tutorial_dialog.dart';
import '../../widgets/floating_image_card.dart';
import '../../widgets/media_gallery_viewer.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final PromotionService promotionService = PromotionService();
  final CustomerService customerService = CustomerService();
  final AuthService authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final CompanyOfferService _companyOfferService = CompanyOfferService();
  final CompanyStoryService _companyStoryService = CompanyStoryService();
  final PublicationViewService _publicationViewService = PublicationViewService();
  final LoyaltyProgramService _loyaltyProgramService = LoyaltyProgramService();
  final CompanyRatingService _companyRatingService = CompanyRatingService();

  Set<String> _viewedStoryIds = <String>{};
  late Future<int> _unreadNotificationsFuture;
  bool loading = true;
  String customerName = '';
  String? customerAvatarUrl;
  Map<String, int> companyPoints = {};
  Map<String, dynamic> _ratings = {};
  List<Promotion> promotions = [];
  List<Map<String, dynamic>> offers = [];
  List<Map<String, dynamic>> stories = [];
  List<Map<String, dynamic>> companies = [];
  List<LoyaltyTransaction> transactions = [];
  String? error;
  bool _locationPromptShown = false;

  // Tamanho dos cards
  static const double _cardWidth = 300;
  static const int _descriptionMaxChars = 80;

  // Cards de oferta
  static const double _offerImageSize = 110;
  static const EdgeInsets _offerPadding = EdgeInsets.fromLTRB(12, 12, 12, 8);

  // Cards de recompensa
  static const double _rewardImageSize = 70;

  // Cards de empresa
  static const double _companyCardWidth = 260;
  static const double _companyCardHeight = 330;

  @override
  void initState() {
    super.initState();
    _unreadNotificationsFuture = _notificationService.getUnreadCount();
    loadData();
  }

  Future<void> redeemPromotion(Promotion promotion) async {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    if (promotion.pointsRequired <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensas sem pontos agora são ofertas.')),
      );
      return;
    }
    if (availablePoints < promotion.pointsRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não possui pontos suficientes.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resgatar recompensa?'),
          content: Text(
            'Empresa: ${promotion.companyName?.trim().isNotEmpty == true ? promotion.companyName!.trim() : 'Empresa'}\n\n'
            'Recompensa: ${promotion.title}\n\n'
            'Você vai utilizar ${promotion.pointsRequired} pontos.\n'
            'Seu saldo atual nesta empresa: $availablePoints pontos.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Resgatar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      final result = await promotionService.redeemPromotion(promotion.id);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Recompensa resgatada! 🎉'),
            content: Text(
              '${result['title']}\n\n'
              'Pontos utilizados: ${result['points_spent']}\n\n'
              'Novo saldo: ${result['new_balance']} pontos.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      await loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _normalizeLocation(String? value) {
    var normalized = (value ?? '').trim().toLowerCase();
    const replacements = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    };
    replacements.forEach((from, to) => normalized = normalized.replaceAll(from, to));
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isSameCustomerCity(Map<String, dynamic>? company, Map<String, dynamic>? profile) {
    final customerCity = _normalizeLocation(profile?['city']?.toString());
    final companyCity = _normalizeLocation(company?['city']?.toString());
    final customerState = _normalizeLocation(profile?['state']?.toString());
    final companyState = _normalizeLocation(company?['state']?.toString());
    if (customerCity.isEmpty || companyCity.isEmpty || customerCity != companyCity) {
      return false;
    }
    // Use UF/full-state equivalence where available; city is the primary filter.
    const stateAliases = {
      'para': 'pa', 'pa': 'pa',
      'sao paulo': 'sp', 'sp': 'sp', 'rio de janeiro': 'rj', 'rj': 'rj',
      'minas gerais': 'mg', 'mg': 'mg', 'bahia': 'ba', 'ba': 'ba',
      'amazonas': 'am', 'am': 'am', 'acre': 'ac', 'ac': 'ac',
      'alagoas': 'al', 'al': 'al', 'amapa': 'ap', 'ap': 'ap',
      'ceara': 'ce', 'ce': 'ce', 'distrito federal': 'df', 'df': 'df',
      'espirito santo': 'es', 'es': 'es', 'goias': 'go', 'go': 'go',
      'maranhao': 'ma', 'ma': 'ma', 'mato grosso': 'mt', 'mt': 'mt',
      'mato grosso do sul': 'ms', 'ms': 'ms', 'paraiba': 'pb', 'pb': 'pb',
      'pernambuco': 'pe', 'pe': 'pe', 'piaui': 'pi', 'pi': 'pi',
      'rio grande do norte': 'rn', 'rn': 'rn', 'rio grande do sul': 'rs', 'rs': 'rs',
      'rondonia': 'ro', 'ro': 'ro', 'roraima': 'rr', 'rr': 'rr',
      'santa catarina': 'sc', 'sc': 'sc',
      'sergipe': 'se', 'se': 'se', 'tocantins': 'to', 'to': 'to',
    };
    final normalizedCustomerState = stateAliases[customerState] ?? customerState;
    final normalizedCompanyState = stateAliases[companyState] ?? companyState;
    return customerState.isEmpty ||
        companyState.isEmpty ||
        normalizedCustomerState == normalizedCompanyState;
  }

  Future<List<Map<String, dynamic>>> _loadOffersSafely(Map<String, dynamic>? profile) async {
    try {
      final results = await _companyOfferService.getPublicOffers();
      return results.where((offer) {
        final company = Map<String, dynamic>.from(offer['companies'] ?? {});
        return _isSameCustomerCity(company, profile);
      }).toList();
    } catch (_) {
      // Offers are supplementary to the customer's core loyalty data.
      // A failure loading them should not prevent the Home from opening.
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCompaniesSafely(Map<String, dynamic>? profile) async {
    try {
      // Discovery is restricted to the customer's exact city on the Home page.
      if ((profile?['city']?.toString().trim() ?? '').isEmpty) {
        return <Map<String, dynamic>>[];
      }
      final results = await _loyaltyProgramService.discoverCompanies(
        city: null,
        state: null,
      );
      final localResults =
          results.where((company) => _isSameCustomerCity(company, profile)).toList();
      final interests = Set<String>.from(profile?['customer_interests'] ?? const []);
      localResults.sort((a, b) {
        final matchA = interests.contains(a['category']?.toString()) ? 1 : 0;
        final matchB = interests.contains(b['category']?.toString()) ? 1 : 0;
        return matchB.compareTo(matchA);
      });
      return localResults;
    } catch (_) {
      // Discovery is secondary to the customer's loyalty information.
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final profile = await customerService.getProfile();
      final results = await Future.wait([
        customerService.getPointsByCompany(),
        customerService.getPromotions(),
        customerService.getTransactions(),
        _loadOffersSafely(profile),
      ]);
      final loadedCompanyPoints = results[0] as Map<String, int>;
      final loadedPromotions = (results[1] as List<Promotion>)
          .where((promotion) => promotion.pointsRequired > 0)
          .toList();
      final loadedTransactions = results[2] as List<LoyaltyTransaction>;
      final loadedOffers = results[3] as List<Map<String, dynamic>>;
      final loadedCompanies = await _loadCompaniesSafely(profile);
      final city = profile?['city']?.toString().trim() ?? '';
      final state = profile?['state']?.toString().trim() ?? '';
      List<Map<String, dynamic>> loadedStories = [];
      if (city.isNotEmpty && state.isNotEmpty) {
        try {
          loadedStories = await _companyStoryService.getPublicStories(
            city: city,
            state: state,
          );
        } catch (_) {
          loadedStories = [];
        }
      }
      final loadedInterests = Set<String>.from(profile?['customer_interests'] ?? const []);
      final viewedStories = await _publicationViewService.getViewedStoryIds();
      loadedStories.sort((a, b) {
        final aSeen = viewedStories.contains(a['id']?.toString()) ? 1 : 0;
        final bSeen = viewedStories.contains(b['id']?.toString()) ? 1 : 0;
        return aSeen.compareTo(bSeen);
      });
      try {
        final ratings = await _companyRatingService.getStats(
          loadedCompanies.map((c) => c['id'].toString()).toList(),
        );
        for (final company in loadedCompanies) {
          final rating = ratings[company['id']?.toString()];
          company['rating_average'] = rating?['average_rating'];
          company['rating_count'] = rating?['rating_count'] ?? 0;
        }
      } catch (_) {}
      loadedOffers.sort((a, b) {
        final categoryA = (a['companies']?['category']?.toString() ?? '');
        final categoryB = (b['companies']?['category']?.toString() ?? '');
        final scoreA = loadedInterests.contains(categoryA) ? 1 : 0;
        final scoreB = loadedInterests.contains(categoryB) ? 1 : 0;
        return scoreB.compareTo(scoreA);
      });
      final companyIdsForRatings = <String>{
        for (final offer in loadedOffers) (offer['companies']?['id'] ?? '').toString(),
        for (final promotion in loadedPromotions) promotion.companyId,
      }..removeWhere((id) => id.isEmpty || id == 'null');
      Map<String, dynamic> loadedRatings = {};
      try {
        loadedRatings = await _companyRatingService.getStats(
          companyIdsForRatings.toList(),
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ratings = loadedRatings;
        customerName = profile?['full_name'] ?? 'Cliente';
        customerAvatarUrl = profile?['avatar_url']?.toString();
        companyPoints = loadedCompanyPoints;
        promotions = loadedPromotions;
        transactions = loadedTransactions;
        offers = loadedOffers;
        stories = loadedStories;
        _viewedStoryIds = viewedStories;
        companies = loadedCompanies;
        loading = false;
      });
      if (!_locationPromptShown &&
          ((profile?['city']?.toString().trim() ?? '').isEmpty ||
              (profile?['state']?.toString().trim() ?? '').isEmpty)) {
        _locationPromptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showLocationSetupNotice();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Não foi possível carregar seus dados.';
        loading = false;
      });
    }
  }

  Future<void> _showLocationSetupNotice() async {
    final shouldEdit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined, size: 36),
        title: const Text('Personalize sua experiência'),
        content: const Text(
          'Configure sua cidade e Estado em Dados Cadastrais para que o Plim mostre ofertas e destaques das empresas da sua região.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Configurar meus dados'),
          ),
        ],
      ),
    );
    if (shouldEdit == true && mounted) {
      await context.push('/profile/edit');
      if (mounted) {
        _locationPromptShown = false;
        await loadData();
      }
    }
  }

  Future<void> _openNotifications() async {
    await context.push('/customer/notifications');
    if (!mounted) return;
    setState(() {
      _unreadNotificationsFuture = _notificationService.getUnreadCount();
    });
  }

  Future<void> logout() async {
    await authService.logout();
    if (!mounted) return;
    context.go('/login');
  }

  /// Abre "Sobre a empresa" usando o contexto da própria tela.
  void _openCompanyDetails(Map<String, dynamic> company) {
    if (!mounted) return;
    context.push('/customer/company-details', extra: company);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: .12),
          backgroundImage: customerAvatarUrl == null || customerAvatarUrl!.isEmpty
              ? null
              : NetworkImage(customerAvatarUrl!),
          child: customerAvatarUrl == null || customerAvatarUrl!.isEmpty
              ? const Icon(Icons.person, size: 20)
              : null,
        ),
        actions: [
          IconButton(
            tooltip: 'Compartilhar Plim',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => ShareService.shareApp(),
          ),
          FutureBuilder<int>(
            future: _unreadNotificationsFuture,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notificações',
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: _openNotifications,
              );
            },
          ),
          IconButton(
            tooltip: 'Suporte ApoloApps',
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () => SupportService.openWhatsApp(context),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loadData,
          ),
          IconButton(
            tooltip: 'Ajuda',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => HelpTutorialDialog.show(context, isCompany: false),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Escanear QR Code',
        onPressed: _openQrOptions,
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * .7),
        Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadData,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        const SizedBox(height: 4),
        if (stories.isNotEmpty) ...[
          _buildStories(),
          const SizedBox(height: 24),
        ],
        _buildOffers(),
        const SizedBox(height: 24),
        _buildCompanies(),
        const SizedBox(height: 24),
        _buildPromotions(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Descobrir empresas e ofertas',
              onPressed: () => context.push('/customer/explore'),
              icon: const Icon(Icons.explore_outlined),
            ),
            IconButton(
              tooltip: 'Programas de fidelidade',
              onPressed: () => context.push('/customer/my-loyalties'),
              icon: const Icon(Icons.loyalty_outlined),
            ),
            const SizedBox(width: 76),
            IconButton(
              tooltip: 'Minhas recompensas',
              onPressed: () => context.push('/customer/my-benefits'),
              icon: const Icon(Icons.card_giftcard_outlined),
            ),
            IconButton(
              tooltip: 'Dados cadastrais',
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQrOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Escanear QR Code'),
                onTap: () => Navigator.pop(sheetContext, 'scan'),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard),
                title: const Text('Inserir código manualmente'),
                onTap: () => Navigator.pop(sheetContext, 'manual'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || option == null) return;
    if (option == 'scan') {
      final result = await context.push<bool>('/customer/scan');
      if (!mounted) return;
      if (result == true) await loadData();
    } else if (option == 'manual') {
      await _enterManualQrCode();
    }
  }

  Future<void> _enterManualQrCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Inserir código manualmente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            labelText: 'Código de validação',
            hintText: 'Digite ou cole o código',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Validar código'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null || code.trim().isEmpty) return;
    try {
      final result = await QrService().redeemQrCode(code.trim());
      if (!mounted) return;
      final pending = result['request_pending'] == true;
      final points = result['points'] ?? result['points_earned'];
      final companyName = result['company_name']?.toString() ?? 'empresa';
      final alreadyPending = result['already_pending'] == true;
      final balance = result['new_balance'];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(pending ? 'Solicitação enviada! 🎉' : 'Pontos recebidos! 🎉'),
          content: Text(
            pending
                ? (alreadyPending
                    ? 'Sua solicitação de $points pontos para o programa de fidelidade da $companyName já está aguardando aprovação da empresa.\n\nVocê poderá inserir outro código após esta solicitação ser analisada.'
                    : 'Você solicitou $points pontos no programa de fidelidade da $companyName.\n\nA empresa precisa aprovar a solicitação antes que os pontos sejam adicionados ao seu saldo. Você receberá uma notificação quando houver uma decisão.')
                : 'Você ganhou $points pontos.\n\nSeu novo saldo é $balance pontos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) await loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openProfile() async {
    final result = await context.push<bool>('/profile/edit');
    if (!mounted) return;
    if (result == true) await loadData();
  }

  // ---------- Destaques ----------

  /// Mídias do destaque. Usa a lista de mídias e, se estiver vazia, a mídia única.
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

  /// Empresa do destaque, com o id garantido quando vier em outro campo.
  Map<String, dynamic> _storyCompany(Map<String, dynamic> story) {
    final company = Map<String, dynamic>.from(story['companies'] ?? {});
    company['id'] ??= story['company_id'] ?? story['companyId'];
    return company;
  }

  void _markStoryViewed(int index) {
    if (index < 0 || index >= stories.length) return;
    final id = stories[index]['id']?.toString();
    if (id == null || id.isEmpty) return;
    _publicationViewService.recordView(type: 'story', id: id);
    if (!mounted) return;
    setState(() => _viewedStoryIds.add(id));
  }

  Future<void> _openStory(int index) async {
    final sequence = [
      for (final story in stories)
        MediaStory(
          urls: _storyMedia(story),
          description: story['description']?.toString(),
          title: _storyCompany(story)['name']?.toString(),
          onTitleTap: () => _openCompanyDetails(_storyCompany(story)),
        ),
    ];
    await showFullscreenStoryViewer(
      context,
      stories: sequence,
      initialStoryIndex: index,
      onStoryViewed: _markStoryViewed,
    );
  }

  Widget _buildStories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Destaques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final story = stories[index];
              final company = _storyCompany(story);
              final media = _storyMedia(story);
              final storyId = story['id']?.toString() ?? '';
              final seen = _viewedStoryIds.contains(storyId);
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
                            color: seen ? Colors.grey : AppColors.primary,
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
                        company['name']?.toString() ?? 'Empresa',
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

  // ---------- Ofertas ----------

  Widget _buildOffers() {
    final visible = offers.take(10).toList();
    // Altura de cada card, calculada pelo conteúdo
    final heights = visible
        .map(
          (offer) => FloatingImageCard.measureHeight(
            context,
            blocks: _offerBlocks(offer),
            imageUrl: _offerImage(offer),
            imageSize: _offerImageSize,
            gap: 12,
            width: _cardWidth,
            padding: _offerPadding,
          ),
        )
        .toList();
    // A lista usa a altura do card mais alto
    final listHeight = heights.fold<double>(0, (acc, h) => h > acc ? h : acc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ofertas para descobrir',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nenhuma oferta disponível no momento.'),
            ),
          )
        else
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: _cardWidth,
                height: heights[index],
                child: _buildOfferCard(visible[index]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/customer/explore'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Ver todas as ofertas e empresas'),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final company = Map<String, dynamic>.from(offer['companies'] ?? {});
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await _publicationViewService.recordView(type: 'offer', id: offer['id'].toString());
          if (!mounted) return;
          context.push('/empresa/${company['id']}?oferta=${offer['id']}');
        },
        child: FloatingImageCard(
          padding: _offerPadding,
          imageUrl: _offerImage(offer).isEmpty ? null : _offerImage(offer),
          imageSize: _offerImageSize,
          blocks: _offerBlocks(offer),
          mediaCount: _offerMediaUrls(offer).length,
          onImageTap: _offerMediaUrls(offer).isEmpty
              ? null
              : () => showFullscreenMediaGallery(
                    context,
                    urls: _offerMediaUrls(offer),
                    title: offer['title']?.toString(),
                    description: offer['description']?.toString(),
                  ),
        ),
      ),
    );
  }

  String _offerImage(Map<String, dynamic> offer) {
    final urls = _offerMediaUrls(offer);
    return offer['image_url']?.toString() ?? (urls.isNotEmpty ? urls.first : '');
  }

  List<String> _offerMediaUrls(Map<String, dynamic> offer) {
    final raw = offer['media_urls'];
    final urls = raw is List
        ? raw.map((value) => value.toString()).where((value) => value.trim().isNotEmpty).toList()
        : <String>[];
    final primary = offer['image_url']?.toString() ?? '';
    if (urls.isEmpty && primary.isNotEmpty) urls.add(primary);
    if (urls.isNotEmpty && primary.isNotEmpty && !urls.contains(primary)) urls.insert(0, primary);
    return urls;
  }

  Widget _offerHeader(Map<String, dynamic> offer, Map<String, dynamic> company) {
    final name = company['name']?.toString() ?? 'Empresa';
    return _companyHeader(
      company: company,
      tooltip: 'Compartilhar oferta',
      onShare: () => ShareService.shareOffer(
        companyName: name,
        title: offer['title']?.toString() ?? 'Oferta',
        description: offer['description']?.toString(),
        companyLogoUrl: company['logo_url']?.toString(),
        companyId: company['id']?.toString(),
        offerId: offer['id']?.toString(),
      ),
    );
  }

  List<FloatBlock> _offerBlocks(Map<String, dynamic> offer) {
    final company = Map<String, dynamic>.from(offer['companies'] ?? {});
    final description = _limitText(offer['description']?.toString() ?? '');
    final endDate = _offerEndDate(offer);
    final validText = endDate == null
        ? 'Validade não informada'
        : 'Válida até ${_formatDateOnly(endDate)}';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    return [
      FloatBlock.widget(
        _offerHeader(offer, company),
        height: 40,
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
        validText,
        bodyStyle.copyWith(
          fontSize: 13,
          color: endDate == null ? Colors.grey : Colors.orange,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
      ),
    ];
  }

  // ---------- Empresas ----------

  Widget _buildCompanies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Empresas para conhecer', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (companies.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Ainda não há empresas disponíveis para mostrar.')))
        else
          SizedBox(
            height: _companyCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: companies.length > 10 ? 10 : companies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final company = companies[index];
                final logo = company['logo_url']?.toString() ?? '';
                final location = [company['city'], company['state']]
                    .where((value) => value != null && value.toString().isNotEmpty)
                    .join(' - ');
                return SizedBox(
                  width: _companyCardWidth,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openCompanyDetails(company),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
                                    child: logo.isEmpty
                                        ? const Icon(Icons.storefront_outlined, size: 30)
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  CompanyRatingDisplay(
                                    average: (company['rating_average'] as num?)?.toDouble(),
                                    count: (company['rating_count'] as num?)?.toInt() ?? 0,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              company['name']?.toString() ?? 'Empresa',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if ((company['category']?.toString() ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.category_outlined, size: 16),
                                  label: Text(
                                    company['category'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (location.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            const Spacer(),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Ver empresa', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  tooltip: 'Compartilhar empresa',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => ShareService.shareCompanyClub(
                                    companyName: company['name']?.toString() ?? 'Empresa',
                                    companyLogoUrl: logo,
                                    companyId: company['id']?.toString(),
                                  ),
                                  icon: const Icon(Icons.share_outlined),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/customer/explore'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Descobrir mais empresas'),
          ),
        ),
      ],
    );
  }

  // ---------- Recompensas ----------

  Widget _buildPromotions() {
    final visible = promotions.take(10).toList();
    final heights = visible
        .map(
          (promotion) => FloatingImageCard.measureHeight(
            context,
            blocks: _rewardBlocks(promotion),
            imageUrl: promotion.imageUrl,
            imageSize: _rewardImageSize,
            gap: 12,
            width: _cardWidth,
            padding: _offerPadding,
          ),
        )
        .toList();
    final listHeight = heights.fold<double>(0, (acc, h) => h > acc ? h : acc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recompensas disponíveis',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhuma recompensa disponível no momento.'),
            ),
          )
        else ...[
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: _cardWidth,
                height: heights[index],
                child: _buildPromotionCard(visible[index]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push(
                '/customer/all-promotions',
                extra: {
                  'promotions': promotions,
                  'companyPoints': companyPoints,
                },
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ver todos'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final left = await context.push<bool>(
            '/customer/company-details',
            extra: <String, dynamic>{
              'id': promotion.companyId,
              'name': promotion.companyName,
              'joined': true,
            },
          );
          if (left == true && mounted) await loadData();
        },
        child: FloatingImageCard(
          imageSize: _rewardImageSize,
          padding: _offerPadding,
          imageUrl: promotion.imageUrl,
          blocks: _rewardBlocks(promotion),
          mediaCount: _promotionMediaUrls(promotion).length,
          onImageTap: _promotionMediaUrls(promotion).isEmpty
              ? null
              : () => showFullscreenMediaGallery(
                    context,
                    urls: _promotionMediaUrls(promotion),
                    title: promotion.title,
                    description: promotion.description,
                  ),
        ),
      ),
    );
  }


  List<String> _promotionMediaUrls(Promotion promotion) {
    final urls = promotion.mediaUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final primary = promotion.imageUrl?.trim() ?? '';
    if (urls.isEmpty && primary.isNotEmpty) urls.add(primary);
    if (urls.isNotEmpty && primary.isNotEmpty && !urls.contains(primary)) {
      urls.insert(0, primary);
    }
    return urls;
  }

  List<FloatBlock> _rewardBlocks(Promotion promotion) {
    final availablePoints = companyPoints[promotion.companyId] ?? 0;
    final canRedeem =
        promotion.pointsRequired > 0 && availablePoints >= promotion.pointsRequired;
    final rewardText = promotion.type == 'discount' && promotion.discountPercentage != null
        ? '${promotion.discountPercentage!.toStringAsFixed(0)}% de desconto'
        : (promotion.giftDescription ?? 'Brinde');
    final description = _limitText(promotion.description ?? '');
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;
    return [
      FloatBlock.widget(_rewardHeader(promotion), height: 40, spacing: 6),
      FloatBlock.text(
        promotion.title,
        bodyStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        spacing: 6,
        maxLines: 2,
        fullWidth: true,
      ),
      FloatBlock.text(
        rewardText,
        bodyStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
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
      if (promotion.endsAt != null)
        FloatBlock.text(
          'Válido até ${_formatDateOnly(promotion.endsAt!.toLocal())}',
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
            : 'Faltam ${promotion.pointsRequired - availablePoints} pontos nesta empresa.',
        bodyStyle.copyWith(
          fontSize: 13,
          color: canRedeem ? Colors.green : Colors.grey,
        ),
        spacing: 8,
        maxLines: 2,
      ),
      FloatBlock.widget(_rewardActions(promotion, canRedeem), height: 40),
    ];
  }

  Widget _rewardHeader(Promotion promotion) {
    final name = promotion.companyName?.trim().isNotEmpty == true
        ? promotion.companyName!.trim()
        : 'Empresa';
    final company = <String, dynamic>{
      'id': promotion.companyId,
      'name': name,
      'logo_url': promotion.companyLogoUrl ?? '',
    };
    return _companyHeader(
      company: company,
      tooltip: 'Compartilhar recompensa',
      onShare: () => ShareService.sharePromotion(
        companyName: name,
        title: promotion.title,
        type: promotion.type,
        discountPercentage: promotion.discountPercentage?.toStringAsFixed(0),
        giftDescription: promotion.giftDescription,
        description: promotion.description,
        companyLogoUrl: promotion.companyLogoUrl,
        companyId: promotion.companyId,
      ),
    );
  }

  /// Linha de ações: pontos e botão de resgate.
  Widget _rewardActions(Promotion promotion, bool canRedeem) {
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
            '${promotion.pointsRequired} pts',
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
            onPressed: canRedeem ? () => redeemPromotion(promotion) : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                canRedeem ? 'Resgatar recompensa' : 'Pontos insuficientes',
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Cabeçalho compartilhado (logo, nome clicável com avaliação, compartilhar) ----------

  Map<String, dynamic>? _ratingOf(String? companyId) {
    if (companyId == null || companyId.isEmpty) return null;
    final value = _ratings[companyId];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Widget _companyHeader({
    required Map<String, dynamic> company,
    required String tooltip,
    required VoidCallback onShare,
  }) {
    final logo = company['logo_url']?.toString() ?? '';
    final name = company['name']?.toString() ?? 'Empresa';
    final companyId = company['id']?.toString();
    final rating = _ratingOf(companyId);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final primary = Theme.of(context).colorScheme.primary;
    final canOpen = companyId != null && companyId.isNotEmpty && companyId != 'null';
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo.isEmpty ? const Icon(Icons.storefront, size: 12) : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: canOpen ? () => _openCompanyDetails(company) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                    decoration: TextDecoration.underline,
                    decorationColor: primary.withValues(alpha: .4),
                  ),
                ),
                CompanyRatingDisplay(
                  average: (rating?['average_rating'] as num?)?.toDouble(),
                  count: (rating?['rating_count'] as num?)?.toInt() ?? 0,
                  compact: true,
                ),
              ],
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

  // ---------- Utilitários ----------

  String _limitText(String text, [int max = _descriptionMaxChars]) {
    final trimmed = text.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max).trimRight()}…';
  }

  DateTime? _offerEndDate(Map<String, dynamic> offer) {
    for (final key in ['ends_at', 'valid_until', 'expires_at']) {
      final value = offer[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final date = DateTime.tryParse(value);
      if (date != null) return date.toLocal();
    }
    return null;
  }

  String _formatDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}