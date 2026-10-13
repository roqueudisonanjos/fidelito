import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/company_dashboard_service.dart';
import '../../services/promotion_service.dart';

class CompanyHomePage extends StatefulWidget {
  const CompanyHomePage({
    super.key,
  });

  @override
  State<CompanyHomePage> createState() =>
      _CompanyHomePageState();
}

class _CompanyHomePageState extends State<CompanyHomePage> {
  // ============================================================
  // SERVICES
  // ============================================================

  final AuthService _authService = AuthService();

  final CompanyDashboardService _dashboardService =
      CompanyDashboardService();

  final PromotionService _promotionService =
      PromotionService();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // DASHBOARD
  // ============================================================

  CompanyDashboardData? _companyData;

  // ============================================================
  // BENEFÍCIOS
  // ============================================================

  String? _companyId;

  List<Map<String, dynamic>> _promotions = [];

  bool _loading = true;

  bool _creating = false;

  String? _error;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ============================================================
  // CARREGAR DADOS
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // --------------------------------------------------------
      // CARREGA DASHBOARD
      // --------------------------------------------------------

      final dashboardData =
          await _dashboardService.loadDashboard();

      // --------------------------------------------------------
      // USUÁRIO LOGADO
      // --------------------------------------------------------

      final user =
          _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Usuário não autenticado.',
        );
      }

      // --------------------------------------------------------
      // BUSCA EMPRESA
      // --------------------------------------------------------

      final company =
          await _supabase
              .from('companies')
              .select()
              .eq('owner_id', user.id)
              .maybeSingle();

      if (company == null) {
        throw Exception(
          'Nenhuma empresa encontrada para este usuário.',
        );
      }

      final companyId =
          company['id']?.toString();

      if (companyId == null ||
          companyId.isEmpty) {
        throw Exception(
          'Não foi possível identificar a empresa.',
        );
      }

      // --------------------------------------------------------
      // BUSCA BENEFÍCIOS
      // --------------------------------------------------------

      final promotions =
          await _promotionService
              .getCompanyPromotions(
        companyId,
      );

      if (!mounted) return;

      setState(() {
        _companyData = dashboardData;

        _companyId = companyId;

        _promotions = promotions;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await _authService.logout();

      if (!mounted) return;

      context.go('/login');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao sair: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CRIAR BENEFÍCIO
  // ============================================================

  Future<void> _showCreatePromotionDialog() async {
    if (_companyId == null) {
      return;
    }

    final formKey =
        GlobalKey<FormState>();

    final titleController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    final pointsController =
        TextEditingController();

    final discountController =
        TextEditingController();

    final giftController =
        TextEditingController();

    String type = 'discount';

    DateTime? startsAt =
        DateTime.now();

    DateTime? endsAt =
        DateTime.now().add(
      const Duration(days: 30),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Novo benefício',
              ),

              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        // ==================================================
                        // TÍTULO
                        // ==================================================

                        TextFormField(
                          controller:
                              titleController,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Título',
                            hintText:
                                'Ex.: 10% de desconto',
                            border:
                                OutlineInputBorder(),
                          ),
                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Informe o título.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ==================================================
                        // DESCRIÇÃO
                        // ==================================================

                        TextFormField(
                          controller:
                              descriptionController,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Descrição',
                            hintText:
                                'Explique o benefício',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ==================================================
                        // TIPO
                        // ==================================================

                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Tipo do benefício',
                            border:
                                OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value:
                                  'discount',
                              child:
                                  Text(
                                'Desconto',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                                  'gift',
                              child:
                                  Text(
                                'Brinde',
                              ),
                            ),
                          ],
                          onChanged:
                              (value) {
                            if (value ==
                                null) {
                              return;
                            }

                            setDialogState(
                              () {
                                type =
                                    value;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ==================================================
                        // PONTOS
                        // ==================================================

                        TextFormField(
                          controller:
                              pointsController,
                          keyboardType:
                              TextInputType.number,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Pontos necessários',
                            border:
                                OutlineInputBorder(),
                          ),
                          validator:
                              (value) {
                            final points =
                                int.tryParse(
                              value ?? '',
                            );

                            if (points ==
                                    null ||
                                points <=
                                    0) {
                              return 'Informe uma quantidade válida.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        // ==================================================
                        // DESCONTO
                        // ==================================================

                        if (type ==
                            'discount')
                          TextFormField(
                            controller:
                                discountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal:
                                  true,
                            ),
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Percentual de desconto',
                              hintText:
                                  'Ex.: 10',
                              suffixText:
                                  '%',
                              border:
                                  OutlineInputBorder(),
                            ),
                            validator:
                                (value) {
                              final discount =
                                  double.tryParse(
                                value
                                        ?.replaceAll(
                                      ',',
                                      '.',
                                    ) ??
                                    '',
                              );

                              if (discount ==
                                      null ||
                                  discount <=
                                      0 ||
                                  discount >
                                      100) {
                                return 'Informe um desconto entre 0 e 100%.';
                              }

                              return null;
                            },
                          ),

                        // ==================================================
                        // BRINDE
                        // ==================================================

                        if (type ==
                            'gift')
                          TextFormField(
                            controller:
                                giftController,
                            maxLines: 2,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Descrição do brinde',
                              hintText:
                                  'Ex.: Design de sobrancelha grátis',
                              border:
                                  OutlineInputBorder(),
                            ),
                            validator:
                                (value) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Informe o brinde.';
                              }

                              return null;
                            },
                          ),

                        const SizedBox(
                          height: 20,
                        ),

                        // ==================================================
                        // DATA INICIAL
                        // ==================================================

                        _buildDateField(
                          context:
                              context,
                          label:
                              'Início da promoção',
                          date:
                              startsAt,
                          onChanged:
                              (date) {
                            setDialogState(
                              () {
                                startsAt =
                                    date;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // ==================================================
                        // DATA FINAL
                        // ==================================================

                        _buildDateField(
                          context:
                              context,
                          label:
                              'Data de validade',
                          date:
                              endsAt,
                          onChanged:
                              (date) {
                            setDialogState(
                              () {
                                endsAt =
                                    date;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        const Text(
                          'Após essa data, o benefício será considerado expirado e não poderá ser resgatado.',
                          style:
                              TextStyle(
                            fontSize:
                                12,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              actions: [
                // ==================================================
                // CANCELAR DIALOG
                // ==================================================

                TextButton(
                  onPressed:
                      _creating
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                  child:
                      const Text(
                    'Cancelar',
                  ),
                ),

                // ==================================================
                // CRIAR
                // ==================================================

                ElevatedButton(
                  onPressed:
                      _creating
                          ? null
                          : () async {
                              if (!formKey
                                  .currentState!
                                  .validate()) {
                                return;
                              }

                              if (startsAt ==
                                      null ||
                                  endsAt ==
                                      null) {
                                return;
                              }

                              if (!endsAt!
                                  .isAfter(
                                startsAt!,
                              )) {
                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'A data de validade deve ser posterior à data de início.',
                                    ),
                                  ),
                                );

                                return;
                              }

                              setDialogState(
                                () {
                                  _creating =
                                      true;
                                },
                              );

                              try {
                                final points =
                                    int.parse(
                                  pointsController
                                      .text
                                      .trim(),
                                );

                                double?
                                    discount;

                                if (type ==
                                    'discount') {
                                  discount =
                                      double.parse(
                                    discountController
                                        .text
                                        .replaceAll(
                                          ',',
                                          '.',
                                        )
                                        .trim(),
                                  );
                                }

                                // ==================================================
                                // CHAMADA AO PROMOTION SERVICE
                                // ==================================================

                                await _promotionService
                                    .createPromotion(
                                  companyId:
                                      _companyId!,
                                  title:
                                      titleController
                                          .text
                                          .trim(),
                                  description:
                                      descriptionController
                                          .text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : descriptionController
                                          .text
                                          .trim(),
                                  type:
                                      type,
                                  pointsRequired:
                                      points,
                                  discountPercentage:
                                      discount,
                                  giftDescription:
                                      type ==
                                              'gift'
                                          ? giftController
                                              .text
                                              .trim()
                                          : null,
                                  startsAt:
                                      startsAt!,
                                  endsAt:
                                      endsAt!,
                                );

                                if (!mounted) {
                                  return;
                                }

                                Navigator.pop(
                                  dialogContext,
                                );

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Benefício criado com sucesso!',
                                    ),
                                  ),
                                );

                                await _loadData();
                              } catch (e) {
                                if (!mounted) {
                                  return;
                                }

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(
                                      e.toString()
                                          .replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                  ),
                                );

                                setDialogState(
                                  () {
                                    _creating =
                                        false;
                                  },
                                );
                              }
                            },
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Criar benefício',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    pointsController.dispose();
    discountController.dispose();
    giftController.dispose();
  }

  // ============================================================
  // CAMPO DE DATA
  // ============================================================

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime>
        onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final selected =
            await showDatePicker(
          context: context,
          initialDate:
              date ?? DateTime.now(),
          firstDate:
              DateTime.now(),
          lastDate:
              DateTime.now().add(
            const Duration(days: 3650),
          ),
        );

        if (selected == null) {
          return;
        }

        onChanged(selected);
      },
      borderRadius:
          BorderRadius.circular(4),
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
          suffixIcon: const Icon(
            Icons.calendar_today,
          ),
        ),
        child: Text(
          date == null
              ? 'Selecione uma data'
              : _formatDate(date),
        ),
      ),
    );
  }

  // ============================================================
  // CANCELAR BENEFÍCIO
  // ============================================================

  Future<void> _cancelPromotion(
    Map<String, dynamic> promotion,
  ) async {
    final id =
        promotion['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancelar benefício?',
          ),
          content: Text(
            'O benefício "${promotion['title']}" será cancelado e não poderá mais ser resgatado pelos clientes.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'Voltar',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text(
                'Cancelar benefício',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      // IMPORTANTE:
      // PromotionService recebe SOMENTE o ID.
      await _promotionService
          .cancelPromotion(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Benefício cancelado.',
          ),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // EXCLUIR BENEFÍCIO
  // ============================================================

  Future<void> _deletePromotion(
    Map<String, dynamic> promotion,
  ) async {
    final id =
        promotion['id']?.toString();

    if (id == null || id.isEmpty) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Excluir benefício?',
          ),
          content: Text(
            'O benefício "${promotion['title']}" será excluído permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'Voltar',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text(
                'Excluir',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      // IMPORTANTE:
      // PromotionService recebe SOMENTE o ID.
      await _promotionService
          .deletePromotion(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Benefício excluído.',
          ),
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          colorScheme.surface,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,

        scrolledUnderElevation: 0,

        backgroundColor:
            colorScheme.surface,

        titleSpacing: 20,

        title: Row(
          children: [
            _CompanyAvatar(
              logoUrl:
                  _companyData
                      ?.companyLogoUrl,
              size: 42,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _companyData
                            ?.companyName ??
                        'Painel da empresa',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    'Painel administrativo',
                    style:
                        TextStyle(
                      fontSize: 12,
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed:
                _loading
                    ? null
                    : _loadData,
            icon:
                const Icon(
              Icons
                  .refresh_rounded,
            ),
          ),

          IconButton(
            tooltip: 'Sair',
            onPressed:
                _logout,
            icon:
                const Icon(
              Icons
                  .logout_rounded,
            ),
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ========================================================
      // BOTÃO NOVO BENEFÍCIO
      // ========================================================

      floatingActionButton:
          _companyId == null ||
                  _loading
              ? null
              : FloatingActionButton.extended(
                  onPressed:
                      _showCreatePromotionDialog,
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'Novo benefício',
                  ),
                ),

      // ========================================================
      // BODY
      // ========================================================

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry:
            _loadData,
      );
    }

    if (_companyData == null) {
      return _ErrorView(
        message:
            'Nenhuma empresa foi encontrada.',
        onRetry:
            _loadData,
      );
    }

    final colorScheme =
        Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _loadData,

      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          120,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // CARD DA EMPRESA
            // ==================================================

            _WelcomeCard(
              company:
                  _companyData!,
            ),

            const SizedBox(
              height: 28,
            ),

            // ==================================================
            // AÇÕES RÁPIDAS
            // ==================================================

            const _SectionTitle(
              title:
                  'Ações rápidas',
              subtitle:
                  'Acesse as principais funções',
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // ESCANEAR BENEFÍCIO
            // ==================================================

            _ScanBenefitCard(
              onTap: () {
                context.push(
                  '/company/scan-benefit',
                );
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // QR + DASHBOARD
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                      _ActionCard(
                    icon: Icons
                        .qr_code_2_rounded,
                    title:
                        'Gerar QR Code',
                    subtitle:
                        'Criar código',
                    onTap: () {
                      context.push(
                        '/company/generate-qr',
                      );
                    },
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      _ActionCard(
                    icon: Icons
                        .dashboard_rounded,
                    title:
                        'Dashboard',
                    subtitle:
                        'Ver resultados',
                    onTap: () {
                      context.push(
                        '/company/dashboard',
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildProfileButton(),

            const SizedBox(height: 24),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // RESUMO
            // ==================================================

            const _SectionTitle(
              title: 'Resumo',
              subtitle:
                  'Visão geral da sua empresa',
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _StatisticCard(
                    icon: Icons
                        .card_giftcard_rounded,
                    value:
                        _companyData!
                            .benefitsUsed
                            .toString(),
                    label:
                        'Benefícios utilizados',
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      _StatisticCard(
                    icon: Icons
                        .people_alt_rounded,
                    value:
                        _companyData!
                            .customersServed
                            .toString(),
                    label:
                        'Clientes atendidos',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _StatisticCard(
                    icon: Icons
                        .qr_code_2_rounded,
                    value:
                        _companyData!
                            .totalQrCodes
                            .toString(),
                    label:
                        'QR Codes gerados',
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      _StatisticCard(
                    icon: Icons
                        .check_circle_outline_rounded,
                    value:
                        _companyData!
                            .usedQrCodes
                            .toString(),
                    label:
                        'QR Codes utilizados',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 30,
            ),

            // ==================================================
            // BENEFÍCIOS
            // ==================================================

            Row(
              children: [
                const Expanded(
                  child:
                      _SectionTitle(
                    title:
                        'Meus benefícios',
                    subtitle:
                        'Gerencie os benefícios oferecidos aos clientes',
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colorScheme
                        .primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child:
                      Text(
                    '${_promotions.length}',
                    style:
                        TextStyle(
                      color: colorScheme
                          .primary,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // LISTA DE BENEFÍCIOS
            // ==================================================

            if (_promotions.isEmpty)
              _buildEmpty()
            else
              ..._promotions.map(
                _buildPromotionCard,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(28),

      decoration:
          BoxDecoration(
        color:
            colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Icon(
            Icons
                .card_giftcard_outlined,
            size: 58,
            color:
                colorScheme
                    .onSurfaceVariant,
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'Nenhum benefício criado',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Crie seu primeiro benefício para que seus clientes possam resgatá-lo.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          ElevatedButton.icon(
            onPressed:
                _showCreatePromotionDialog,
            icon:
                const Icon(
              Icons.add,
            ),
            label:
                const Text(
              'Criar benefício',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          await context.push(
            '/profile/editCompany',
          );

          if (!mounted) return;

          //await _loadDashboard();
        },
        icon: const Icon(
          Icons.person_outline,
        ),
        label: const Text(
          'Dados cadastrais',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD BENEFÍCIO
  // ============================================================

  Widget _buildPromotionCard(
    Map<String, dynamic>
        promotion,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final title =
        promotion['title'] ??
            'Benefício';

    final description =
        promotion['description'];

    final type =
        promotion['type'];

    final points =
        promotion['points_required'] ??
            0;

    final discount =
        promotion[
            'discount_percentage'];

    final gift =
        promotion[
            'gift_description'];

    final active =
        promotion['active'] ?? true;

    final startsAt =
        _parseDate(
      promotion['starts_at'],
    );

    final endsAt =
        _parseDate(
      promotion['ends_at'],
    );

    final now =
        DateTime.now();

    final expired =
        endsAt != null &&
            now.isAfter(endsAt);

    final notStarted =
        startsAt != null &&
            now.isBefore(startsAt);

    String status;

    if (!active) {
      status = 'Cancelado';
    } else if (expired) {
      status = 'Expirado';
    } else if (notStarted) {
      status = 'Agendado';
    } else {
      status = 'Ativo';
    }

    Color statusColor;

    IconData statusIcon;

    switch (status) {
      case 'Cancelado':
        statusColor =
            Colors.red;
        statusIcon =
            Icons.cancel;
        break;

      case 'Expirado':
        statusColor =
            Colors.orange;
        statusIcon =
            Icons.timer_off;
        break;

      case 'Agendado':
        statusColor =
            Colors.blue;
        statusIcon =
            Icons.schedule;
        break;

      default:
        statusColor =
            Colors.green;
        statusIcon =
            Icons.check_circle;
    }

    // ==========================================================
    // TEXTO DO BENEFÍCIO
    // ==========================================================

    String rewardText;

    if (type == 'discount' &&
        discount != null) {
      rewardText =
          '${discount.toString()}% de desconto';
    } else if (type == 'gift' &&
        gift != null) {
      rewardText =
          gift.toString();
    } else {
      rewardText =
          'Benefício';
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ==================================================
          // TÍTULO + STATUS
          // ==================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Expanded(
                child: Text(
                  title.toString(),
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              _buildStatusChip(
                status,
                statusColor,
                statusIcon,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          // ==================================================
          // RECOMPENSA
          // ==================================================

          Text(
            rewardText,
            style:
                TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
              color:
                  colorScheme.primary,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // ==================================================
          // PONTOS
          // ==================================================

          Row(
            children: [
              Icon(
                Icons
                    .stars_outlined,
                size: 19,
                color:
                    colorScheme.primary,
              ),

              const SizedBox(
                width: 6,
              ),

              Text(
                '$points pontos necessários',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          // ==================================================
          // DESCRIÇÃO
          // ==================================================

          if (description !=
                  null &&
              description
                  .toString()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),

            Text(
              description.toString(),
              style:
                  TextStyle(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],

          const Divider(
            height: 26,
          ),

          // ==================================================
          // INÍCIO
          // ==================================================

          if (startsAt !=
              null)
            Row(
              children: [
                const Icon(
                  Icons
                      .play_circle_outline,
                  size: 18,
                ),

                const SizedBox(
                  width: 7,
                ),

                Text(
                  'Início: ${_formatDate(startsAt)}',
                ),
              ],
            ),

          const SizedBox(
            height: 7,
          ),

          // ==================================================
          // VALIDADE
          // ==================================================

          if (endsAt !=
              null)
            Row(
              children: [
                Icon(
                  Icons
                      .event_outlined,
                  size: 18,
                  color:
                      expired
                          ? Colors
                              .orange
                          : null,
                ),

                const SizedBox(
                  width: 7,
                ),

                Text(
                  'Validade: ${_formatDate(endsAt)}',
                  style:
                      TextStyle(
                    color:
                        expired
                            ? Colors
                                .orange
                            : null,
                    fontWeight:
                        expired
                            ? FontWeight
                                .bold
                            : null,
                  ),
                ),
              ],
            ),

          const SizedBox(
            height: 16,
          ),

          // ==================================================
          // AÇÕES
          // ==================================================

          if (active &&
              !expired) ...[
            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        () =>
                            _cancelPromotion(
                      promotion,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .cancel_outlined,
                    ),
                    label:
                        const Text(
                      'Cancelar',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      OutlinedButton.icon(
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          Colors.red,
                    ),
                    onPressed:
                        () =>
                            _deletePromotion(
                      promotion,
                    ),
                    icon:
                        const Icon(
                      Icons
                          .delete_outline,
                    ),
                    label:
                        const Text(
                      'Excluir',
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width:
                  double.infinity,

              child:
                  OutlinedButton.icon(
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      Colors.red,
                ),
                onPressed:
                    () =>
                        _deletePromotion(
                  promotion,
                ),
                icon:
                    const Icon(
                  Icons
                      .delete_outline,
                ),
                label:
                    const Text(
                  'Excluir',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _buildStatusChip(
    String status,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: .10,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            status,
            style:
                TextStyle(
              color: color,
              fontSize: 12,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATAS
  // ============================================================

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final year =
        local.year.toString();

    return '$day/$month/$year';
  }
}

// ═══════════════════════════════════════════════════════════
// WELCOME CARD
// ═══════════════════════════════════════════════════════════

class _WelcomeCard
    extends StatelessWidget {
  final CompanyDashboardData company;

  const _WelcomeCard({
    required this.company,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(22),

      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary
                .withValues(alpha: .75),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        boxShadow: [
          BoxShadow(
            color:
                colorScheme.primary
                    .withValues(alpha: .20),
            blurRadius: 20,
            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          _CompanyAvatar(
            logoUrl:
                company.companyLogoUrl,
            size: 58,
            backgroundColor:
                Colors.white
                    .withValues(
              alpha: .15,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            'Olá! 👋',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 15,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            company.companyName,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          if (company
                      .companyDescription !=
                  null &&
              company
                  .companyDescription!
                  .isNotEmpty) ...[
            const SizedBox(
              height: 6,
            ),

            Text(
              company
                  .companyDescription!,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color: Colors.white
                    .withValues(
                  alpha: .85,
                ),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(
            height: 18,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 12,
              vertical: 8,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha: .13,
              ),
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),

            child:
                const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons
                      .check_circle_rounded,
                  color:
                      Colors.white,
                  size: 16,
                ),
                SizedBox(
                  width: 6,
                ),
                Text(
                  'Empresa ativa',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SCAN BENEFIT CARD
// ═══════════════════════════════════════════════════════════

class _ScanBenefitCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanBenefitCard({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Material(
      color:
          colorScheme.primary,
      borderRadius:
          BorderRadius.circular(
        22,
      ),

      child:
          InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          22,
        ),

        child:
            Padding(
          padding:
              const EdgeInsets
                  .all(20),

          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withValues(
                    alpha: .15,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    17,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .qr_code_scanner_rounded,
                  color:
                      Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Escanear benefício',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Text(
                      'Leia o QR Code do cliente para validar o benefício.',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            13,
                        height:
                            1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color:
                    Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ACTION CARD
// ═══════════════════════════════════════════════════════════

class _ActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Material(
      color:
          colorScheme
              .surfaceContainerHighest,
      borderRadius:
          BorderRadius.circular(
        20,
      ),

      child:
          InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),

        child:
            Padding(
          padding:
              const EdgeInsets
                  .all(18),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Container(
                width: 48,
                height: 48,

                decoration:
                    BoxDecoration(
                  color:
                      colorScheme
                          .primary
                          .withValues(
                    alpha: .12,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),

                child:
                    Icon(
                  icon,
                  color:
                      colorScheme
                          .primary,
                  size: 25,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                subtitle,
                style:
                    TextStyle(
                  fontSize: 12,
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATISTIC CARD
// ═══════════════════════════════════════════════════════════

class _StatisticCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatisticCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color:
                colorScheme.primary,
            size: 24,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            label,
            maxLines: 2,
            style:
                TextStyle(
              fontSize: 12,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COMPANY AVATAR
// ═══════════════════════════════════════════════════════════

class _CompanyAvatar
    extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final Color? backgroundColor;

  const _CompanyAvatar({
    required this.logoUrl,
    required this.size,
    this.backgroundColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    final background =
        backgroundColor ??
            colorScheme
                .primary
                .withValues(
              alpha: .12,
            );

    if (logoUrl != null &&
        logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(
          size * .28,
        ),

        child:
            Image.network(
          logoUrl!,
          width: size,
          height: size,
          fit:
              BoxFit.cover,

          errorBuilder:
              (_, _, _) {
            return _fallback(
              background,
              colorScheme,
            );
          },
        ),
      );
    }

    return _fallback(
      background,
      colorScheme,
    );
  }

  Widget _fallback(
    Color background,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: size,
      height: size,

      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          size * .28,
        ),
      ),

      child:
          Icon(
        Icons
            .storefront_rounded,
        size:
            size * .5,
        color:
            colorScheme.primary,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════════════════

class _SectionTitle
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        Text(
          subtitle,
          style:
              TextStyle(
            fontSize: 12,
            color: colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ERROR VIEW
// ═══════════════════════════════════════════════════════════

class _ErrorView
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 56,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Não foi possível carregar os dados',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
                  onRetry,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'Tentar novamente',
              ),
            ),
          ],
        ),
      ),
    );
  }
}