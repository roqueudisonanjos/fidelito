
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

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
  bool loading = false;
  bool obscurePassword = true;
  String? message;

  Future<void> register() async {
    final name = nameController.text.trim();
    final whatsapp = whatsappController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    // Mantém somente os números digitados.
    final whatsappDigits = whatsapp.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (name.isEmpty ||
        whatsapp.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      setState(() {
        message = 'Preencha todos os campos.';
      });
      return;
    }

    // Número brasileiro com DDD: 10 ou 11 dígitos.
    if (whatsappDigits.length != 10 &&
        whatsappDigits.length != 11) {
      setState(() {
        message =
            'Informe um WhatsApp válido com DDD.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        message =
            'A senha deve ter pelo menos 6 caracteres.';
      });
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
      );

      if (!mounted) return;

      if (response.session != null) {
        context.go('/home');
      } else {
        setState(() {
          message =
              'Cadastro realizado. Verifique seu e-mail.';
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
      appBar: AppBar(
        title: const Text('Criar conta'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (obrigatório)',
                    hintText: '(94) 99999-9999',
                    prefixIcon: Icon(Icons.phone_android),
                    helperText: 'Informe o DDD e o número',
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
                          'Acumular pontos e receber benefícios',
                        ),
                      ),
                      RadioListTile<String>(
                        value: 'company_owner',
                        title: Text('Empresa'),
                        subtitle: Text(
                          'Criar programa de fidelidade',
                        ),
                      ),
                    ],
                  ),
                ),

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
    );
  }
}
