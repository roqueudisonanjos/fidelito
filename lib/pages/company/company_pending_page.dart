
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyPendingPage extends StatefulWidget {
  const CompanyPendingPage({super.key});

  @override
  State<CompanyPendingPage> createState() => _CompanyPendingPageState();
}

class _CompanyPendingPageState extends State<CompanyPendingPage> {
  bool _sending = false;

  Future<void> _resendNotification() async {
    setState(() => _sending = true);

    try {
      final result = await Supabase.instance.client.functions.invoke(
        'notify-company-registration',
      );

      if (!mounted) return;

      if (result.status >= 200 && result.status < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação enviada para nossa equipe.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível reenviar a solicitação.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao enviar a solicitação. Tente novamente mais tarde.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro em análise'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 72,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  'Estamos analisando seu cadastro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sua empresa ainda não foi aprovada. '
                  'Nossa equipe entrará em contato pelo WhatsApp informado '
                  'no cadastro. Aguarde nosso contato para liberar o acesso '
                  'ao painel.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _sending ? null : _resendNotification,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.mark_email_unread_outlined),
                    label: Text(
                      _sending
                          ? 'Enviando...'
                          : 'Reenviar solicitação',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Voltar ao login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
