import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {

  final nameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final authService = AuthService();

  String role = 'customer';

  bool loading = false;

  String? message;


  Future<void> register() async {

    final name =
        nameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;


    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {

      setState(() {
        message =
            'Preencha todos os campos.';
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

    } catch (_) {

      if (!mounted) return;

      setState(() {
        message =
            'Não foi possível criar a conta.';
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
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Criar conta',
        ),
      ),

      body: Center(

        child: ConstrainedBox(

          constraints:
              const BoxConstraints(
            maxWidth: 420,
          ),

          child: SingleChildScrollView(

            padding:
                const EdgeInsets.all(24),

            child: Column(

              children: [

                TextField(
                  controller:
                      nameController,

                  decoration:
                      const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon:
                        Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller:
                      emailController,

                  keyboardType:
                      TextInputType.emailAddress,

                  decoration:
                      const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon:
                        Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller:
                      passwordController,

                  obscureText: true,

                  decoration:
                      const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon:
                        Icon(Icons.lock_outline),
                  ),
                ),

                const SizedBox(height: 24),

                const Align(
                  alignment:
                      Alignment.centerLeft,

                  child: Text(
                    'Tipo de conta',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                RadioListTile<String>(
                  value: 'customer',
                  groupValue: role,

                  title:
                      const Text('Cliente'),

                  subtitle:
                      const Text(
                    'Acumular pontos e receber benefícios',
                  ),

                  onChanged: (value) {
                    setState(() {
                      role = value!;
                    });
                  },
                ),

                RadioListTile<String>(
                  value: 'company_owner',
                  groupValue: role,

                  title:
                      const Text('Empresa'),

                  subtitle:
                      const Text(
                    'Criar programa de fidelidade',
                  ),

                  onChanged: (value) {
                    setState(() {
                      role = value!;
                    });
                  },
                ),

                if (message != null) ...[

                  const SizedBox(height: 16),

                  Text(
                    message!,
                    textAlign:
                        TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(

                  width:
                      double.infinity,

                  child:
                      ElevatedButton(

                    onPressed:
                        loading
                            ? null
                            : register,

                    child: loading

                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(),
                          )

                        : const Text(
                            'Criar conta',
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