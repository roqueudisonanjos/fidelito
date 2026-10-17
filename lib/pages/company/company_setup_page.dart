import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/company_service.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({
    super.key,
  });

  @override
  State<CompanySetupPage> createState() =>
      _CompanySetupPageState();
}

class _CompanySetupPageState
    extends State<CompanySetupPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _addressController =
      TextEditingController();

  final CompanyService _companyService =
      CompanyService();

  bool _loading = true;

  bool _saving = false;

  bool _editing = false;

  String? _error;

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCompany();
  }

  // ============================================================
  // CARREGAR EMPRESA
  // ============================================================

  Future<void> _loadCompany() async {
    try {
      final company =
          await _companyService.getMyCompany();

      if (!mounted) return;

      if (company != null) {
        _nameController.text =
            company['name']?.toString() ?? '';

        _descriptionController.text =
            company['description']
                    ?.toString() ??
                '';

        _phoneController.text =
            company['phone']?.toString() ?? '';

        _addressController.text =
            company['address']?.toString() ??
                '';

        setState(() {
          _editing = true;
          _loading = false;
        });
      } else {
        setState(() {
          _editing = false;
          _loading = false;
        });
      }
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
  // SALVAR
  // ============================================================

  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    var emailSent = false;

    try {
      if (_editing) {
        await _companyService.updateCompany(
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

      // Cria a empresa. Ela deve permanecer pendente de aprovação.
      await _companyService.createCompany(
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
      );

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

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Dados da empresa'
              : 'Configurar empresa',
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _buildForm(),
    );
  }

  // ============================================================
  // FORMULÁRIO
  // ============================================================

  Widget _buildForm() {
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 600,
        ),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 20,
                ),

                Icon(
                  _editing
                      ? Icons
                          .business_outlined
                      : Icons.business,
                  size: 70,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  _editing
                      ? 'Dados da empresa'
                      : 'Configure sua empresa',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  _editing
                      ? 'Atualize as informações da sua empresa.'
                      : 'Essas informações serão utilizadas no seu perfil dentro do SaveGift.',
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(
                  height: 32,
                ),

                // ==================================================
                // NOME
                // ==================================================

                TextFormField(
                  controller:
                      _nameController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Nome da empresa',
                    prefixIcon:
                        Icon(Icons.business),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Informe o nome da empresa.';
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
                      _descriptionController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Descrição',
                    hintText:
                        'Ex.: Serviços de estética variados',
                    alignLabelWithHint:
                        true,
                    prefixIcon:
                        Icon(Icons.description),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // WHATSAPP
                // ==================================================

                TextFormField(
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'WhatsApp',
                    prefixIcon:
                        Icon(Icons.phone),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final numbers =
                        value
                                ?.replaceAll(
                              RegExp(r'\D'),
                              '',
                            ) ??
                            '';

                    if (numbers.length <
                        10) {
                      return 'Informe um WhatsApp válido.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // ENDEREÇO
                // ==================================================

                TextFormField(
                  controller:
                      _addressController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Endereço',
                    hintText:
                        'Ex.: Rua Goiás, Número 81, Getat',
                    alignLabelWithHint:
                        true,
                    prefixIcon:
                        Icon(
                      Icons.location_on,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // ERRO
                // ==================================================

                if (_error != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),
                    child: Text(
                      _error!,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),

                // ==================================================
                // BOTÃO
                // ==================================================

                SizedBox(
                  height: 52,
                  child:
                      ElevatedButton(
                    onPressed:
                        _saving
                            ? null
                            : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _editing
                                ? 'Salvar alterações'
                                : 'Criar empresa',
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