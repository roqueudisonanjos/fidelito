import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final authService = AuthService();

  bool loading = false;

  String? error;


  Future<void> login() async {

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {

      setState(() {
        error = 'Informe e-mail e senha.';
      });

      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {

      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      context.go('/home');

    } on AuthException catch (e) {

      if (!mounted) return;

      setState(() {
        error = e.message;
      });

    } catch (_) {

      if (!mounted) return;

      setState(() {
        error =
            'Não foi possível realizar o login.';
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
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: ConstrainedBox(

          constraints:
              const BoxConstraints(
            maxWidth: 420,
          ),

          child: Padding(

            padding:
                const EdgeInsets.all(24),

            child: Column(

              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                const Text(
                  'Fidelito',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Fidelidade que gera benefícios',
                ),

                const SizedBox(height: 40),

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

                  onSubmitted: (_) => login(),
                ),

                if (error != null) ...[

                  const SizedBox(height: 16),

                  Text(
                    error!,
                    textAlign:
                        TextAlign.center,

                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .error,
                    ),
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
                            : login,

                    child: loading

                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(),
                          )

                        : const Text(
                            'Entrar',
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    context.go('/register');
                  },
                  child: const Text(
                    'Criar uma conta',
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