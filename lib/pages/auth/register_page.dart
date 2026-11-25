import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../core/config/business_categories.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final whatsappController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();

  String role = 'customer';
  final Set<String> customerInterests = {};
  String? businessCategory;
  bool loading = false;
  bool obscurePassword = true;
  String? message;

  Future<void> register() async {
    final name = nameController.text.trim();
    final whatsapp = whatsappController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    // Mantém somente os números digitados.
    final whatsappDigits = whatsapp.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty || whatsapp.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        message = 'Preencha todos os campos.';
      });
      return;
    }

    // Número brasileiro com DDD: 10 ou 11 dígitos.
    if (whatsappDigits.length != 10 && whatsappDigits.length != 11) {
      setState(() {
        message = 'Informe um WhatsApp válido com DDD.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        message = 'A senha deve ter pelo menos 6 caracteres.';
      });
      return;
    }

    if (role == 'company_owner' && businessCategory == null) {
      setState(() { message = 'Selecione a categoria da empresa.'; });
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final response = await authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        whatsapp: whatsappDigits,
        customerInterests: role == 'customer' ? customerInterests.toList() : const [],
        businessCategory: role == 'company_owner' ? businessCategory : null,
      );

      if (!mounted) return;

      if (response.session != null) {
        context.go('/home');
      } else {
        setState(() {
          message = 'Cadastro realizado. Verifique seu e-mail.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        message = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        message =
            'Não foi possível criar a conta. Verifique os dados e tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    whatsappController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vamos começar?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text('Crie sua conta para aproveitar o Vanty.'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: role == 'company_owner'
                            ? 'Nome do responsável'
                            : 'Nome',
                        prefixIcon: Icon(Icons.person_outline),
                        helperText: role == 'company_owner'
                            ? 'Pessoa responsável pela conta da empresa'
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: role == 'company_owner'
                            ? 'WhatsApp do responsável'
                            : 'WhatsApp (obrigatório)',
                        hintText: '(94) 99999-9999',
                        prefixIcon: Icon(Icons.phone_android),
                        helperText: role == 'company_owner'
                            ? 'Será sugerido também como contato da empresa'
                            : 'Informe o DDD e o número',
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tipo de conta',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    RadioGroup<String>(
                      groupValue: role,
                      onChanged: (String? value) {
                        if (loading || value == null) return;
                        setState(() {
                          role = value;
                        });
                      },
                      child: Column(
                        children: const [
                          RadioListTile<String>(
                            value: 'customer',
                            title: Text('Cliente'),
                            subtitle: Text(
                              'Acumular pontos e receber recompensas',
                            ),
                          ),
                          RadioListTile<String>(
                            value: 'company_owner',
                            title: Text('Empresa'),
                            subtitle: Text('Criar programa de fidelidade'),
                          ),
                        ],
                      ),
                    ),

                    if (role == 'customer') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Seus interesses', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      const Text('Escolha categorias para receber ofertas mais relevantes.', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: businessCategories.map((category) => FilterChip(
                          label: Text(category),
                          selected: customerInterests.contains(category),
                          onSelected: loading ? null : (selected) {
                            setState(() {
                              if (selected) {
                                customerInterests.add(category);
                              } else {
                                customerInterests.remove(category);
                              }
                            });
                          },
                        )).toList(),
                      ),
                    ],
                    if (role == 'company_owner') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Categoria da empresa *', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: businessCategory,
                        decoration: const InputDecoration(labelText: 'Selecione a categoria'),
                        items: businessCategories.map((category) => DropdownMenuItem(
                          value: category, child: Text(category),
                        )).toList(),
                        onChanged: loading ? null : (value) => setState(() => businessCategory = value),
                        validator: role == 'company_owner' ? (value) => value == null ? 'Selecione uma categoria.' : null : null,
                      ),
                    ],

                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : register,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Criar conta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
