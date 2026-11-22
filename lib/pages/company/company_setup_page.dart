import 'package:flutter/material.dart';

import '../../widgets/company/company_bottom_navigation.dart';
import '../../widgets/company/company_app_bar_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/company_service.dart';
import '../../core/config/business_categories.dart';
import '../../services/image_upload_service.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/delete_account_section.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({super.key});

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _phoneController = TextEditingController();

  final _addressController = TextEditingController();

  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  final CompanyService _companyService = CompanyService();

  bool _loading = true;
  bool _uploadingLogo = false;
  String? _logoUrl;
  String? _businessCategory;
  final ImageUploadService _imageUploadService = ImageUploadService();

  bool _saving = false;

  bool _editing = false;

  String? _error;

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  @override
  void initState() {
    super.initState();

    _businessCategory = Supabase.instance.client.auth.currentUser?.userMetadata?['business_category']?.toString();
    _loadCompany();
  }

  // ============================================================
  // CARREGAR EMPRESA
  // ============================================================

  Future<void> _loadCompany() async {
    try {
      final company = await _companyService.getMyCompany();

      if (!mounted) return;

      if (company != null) {
        _nameController.text = company['name']?.toString() ?? '';

        _descriptionController.text = company['description']?.toString() ?? '';

        _phoneController.text = company['phone']?.toString() ?? '';

        _addressController.text = company['address']?.toString() ?? '';
        _cityController.text = company['city']?.toString() ?? '';
        _stateController.text = company['state']?.toString() ?? '';
        _instagramController.text = company['instagram_username']?.toString() ?? '';
        _tiktokController.text = company['tiktok_username']?.toString() ?? '';
        _businessCategory = company['category']?.toString() ?? _businessCategory;
        _logoUrl = company['logo_url']?.toString();

        setState(() {
          _editing = true;
          _loading = false;
        });
      } else {
        // Aproveita os dados informados na criação da conta para evitar
        // que o responsável precise digitar nome e WhatsApp novamente.
        // Os campos continuam editáveis caso os dados comerciais sejam diferentes.
        final user = Supabase.instance.client.auth.currentUser;
        final metadata = user?.userMetadata ?? <String, dynamic>{};
        Map<String, dynamic>? profile;

        if (user != null) {
          try {
            profile = await Supabase.instance.client
                .from('profiles')
                .select('full_name, whatsapp')
                .eq('id', user.id)
                .maybeSingle();
          } catch (error) {
            debugPrint(
              'Não foi possível carregar os dados do perfil para pré-preencher a empresa: $error',
            );
          }
        }

        if (!mounted) return;

        String firstNonEmpty(List<dynamic> values) {
          for (final value in values) {
            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
          return '';
        }

        _nameController.text = firstNonEmpty([
          profile?['full_name'],
          metadata['full_name'],
        ]);
        _phoneController.text = firstNonEmpty([
          profile?['whatsapp'],
          metadata['phone'],
        ]);

        setState(() {
          _editing = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // SALVAR
  // ============================================================

  Future<void> _pickLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      final url = await _imageUploadService.pickAndUpload(
        folder: 'companies',
        filePrefix: 'logo',
      );
      if (url != null && mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_businessCategory == null) {
      setState(() => _error = 'Selecione a categoria da empresa.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    var emailSent = false;

    try {
      if (_editing) {
        await _companyService.updateCompany(
          category: _businessCategory,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          logoUrl: _logoUrl,
          instagramUsername: _instagramController.text.trim(),
          tiktokUsername: _tiktokController.text.trim(),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados da empresa atualizados com sucesso.'),
          ),
        );

        context.go('/company');
        return;
      }

      // Cria a empresa e libera o acesso automaticamente.
      await _companyService.createCompany(
        category: _businessCategory!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
      );
      // Salva logo e redes sociais opcionais no registro recém-criado,
      // somente se algum desses dados foi informado.
      if ((_logoUrl ?? '').trim().isNotEmpty ||
          _instagramController.text.trim().isNotEmpty ||
          _tiktokController.text.trim().isNotEmpty) {
        await _companyService.updateCompany(
          category: _businessCategory,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          logoUrl: _logoUrl,
          instagramUsername: _instagramController.text.trim(),
          tiktokUsername: _tiktokController.text.trim(),
        );
      }

      // O cadastro já foi salvo; agora tentamos enviar a notificação.

      try {
        final result = await Supabase.instance.client.functions.invoke(
          'notify-company-registration',
        );

        emailSent = result.status >= 200 && result.status < 300;

        debugPrint('Status da notificação: ${result.status}');
        debugPrint('Resposta da notificação: ${result.data}');
      } catch (error, stackTrace) {
        debugPrint('ERRO AO ENVIAR E-MAIL: $error');
        debugPrint('STACK TRACE: $stackTrace');
        emailSent = false;
      }

      if (!mounted) return;

      setState(() => _saving = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cadastro recebido'),
            content: Text(
              emailSent
                  ? 'Recebemos os dados da sua empresa! '
                        'Nossa equipe entrará em contato pelo WhatsApp informado. '
                        'Aguarde nosso contato. '
                        'Seu acesso será liberado após a aprovação.'
                  : 'Os dados da sua empresa foram salvos, mas não conseguimos '
                        'enviar a notificação para nossa equipe. '
                        'Seu cadastro continua pendente. '
                        'Entre novamente para tentar reenviar a solicitação.',
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  await Supabase.instance.client.auth.signOut();

                  if (mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Voltar ao login'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Não foi possível cadastrar a empresa: $error';
      });
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Dados da empresa' : 'Configurar empresa'),
        actions: _editing
            ? [
                TextButton(
                  onPressed: _saving || _loading ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar'),
                ),
                const CompanyAppBarActions(),
              ]
            : null,
      ),
      bottomNavigationBar: _editing ? const CompanyBottomNavigation(selectedIndex: 2) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  // ============================================================
  // FORMULÁRIO
  // ============================================================

  Widget _buildForm() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                Icon(
                  _editing ? Icons.business_outlined : Icons.business,
                  size: 70,
                ),

                const SizedBox(height: 20),

                Text(
                  _editing ? 'Dados da empresa' : 'Configure sua empresa',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _editing
                      ? 'Atualize as informações da sua empresa.'
                      : 'Essas informações serão utilizadas no seu perfil dentro do Fidelito.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundImage: _logoUrl == null || _logoUrl!.isEmpty
                            ? null
                            : NetworkImage(_logoUrl!),
                        child: _logoUrl == null || _logoUrl!.isEmpty
                            ? const Icon(Icons.storefront, size: 42)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadingLogo ? null : _pickLogo,
                        icon: _uploadingLogo
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          _uploadingLogo
                              ? 'Enviando imagem...'
                              : 'Escolher foto da empresa',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==================================================
                // CATEGORIA
                // ==================================================
                DropdownButtonFormField<String>(
                  initialValue: _businessCategory,
                  decoration: const InputDecoration(labelText: 'Categoria da empresa *'),
                  items: businessCategories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: _saving ? null : (value) => setState(() => _businessCategory = value),
                  validator: (value) => value == null ? 'Selecione uma categoria.' : null,
                ),
                const SizedBox(height: 16),

                // NOME
                // ==================================================
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da empresa',
                    helperText:
                        'Preenchido com o nome do cadastro. Altere se o nome comercial for diferente.',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da empresa.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ==================================================
                // DESCRIÇÃO
                // ==================================================
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: Serviços de estética variados',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // WHATSAPP
                // ==================================================
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp comercial',
                    helperText:
                        'Preenchido com o WhatsApp do cadastro. Altere se a empresa usar outro número.',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final numbers = value?.replaceAll(RegExp(r'\D'), '') ?? '';

                    if (numbers.length < 10) {
                      return 'Informe um WhatsApp válido.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ==================================================
                // ENDEREÇO
                // ==================================================
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    hintText: 'Ex.: Rua Goiás, Número 81, Getat',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Cidade',
                    hintText: 'Ex.: Tucuruí',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe a cidade da empresa.'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _stateController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'UF',
                    hintText: 'Ex.: PA',
                    prefixIcon: Icon(Icons.map_outlined),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // REDES SOCIAIS (OPCIONAIS)
                // ==================================================
                Text(
                  'Redes sociais (opcional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instagramController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Instagram',
                    hintText: '@nomedaempresa',
                    prefixIcon: Icon(Icons.camera_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tiktokController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'TikTok',
                    hintText: '@nomedaempresa',
                    prefixIcon: Icon(Icons.music_note_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ==================================================
                // ERRO
                // ==================================================
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                const ChangePasswordSection(),
                const SizedBox(height: 20),
                const DeleteAccountSection(isCompany: true),
                const SizedBox(height: 20),

                // ==================================================
                // BOTÃO DE CRIAÇÃO (na edição, salvar fica no topo)
                // ==================================================
                if (!_editing) SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _editing ? 'Salvar alterações' : 'Criar empresa',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
