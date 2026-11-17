import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteAccountSection extends StatefulWidget {
  const DeleteAccountSection({super.key, required this.isCompany});

  final bool isCompany;

  @override
  State<DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<DeleteAccountSection> {
  bool _loading = false;

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    var obscure = true;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmar encerramento da conta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isCompany
                    ? 'A exclusão só poderá ser feita depois que a empresa estiver desativada. A exclusão é permanente e remove o acesso do responsável.'
                    : 'Sua conta será excluída. Seus pontos, participações em programas e histórico de recompensas serão removidos. Esta ação não poderá ser desfeita.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Por segurança, informe sua senha atual para confirmar.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, passwordController.text),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
    if (password == null) return;
    if (password.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe sua senha atual.')),
        );
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        throw Exception(
          'Não foi possível identificar sua conta. Entre novamente e tente outra vez.',
        );
      }

      if (widget.isCompany) {
        final company = await supabase
            .from('companies')
            .select('active')
            .eq('owner_id', user.id)
            .maybeSingle();
        if (company != null && company['active'] == true) {
          throw Exception(
            'Antes de excluir a conta, desative sua empresa na área administrativa. Depois, volte aqui para concluir a exclusão.',
          );
        }
      }

      // Reautentica o titular antes de permitir uma operação irreversível.
      await supabase.auth.signInWithPassword(email: email, password: password);
      final response = await supabase.functions.invoke(
        'account-management',
        body: {
          'action': widget.isCompany
              ? 'delete_company_account'
              : 'delete_customer_account',
        },
      );
      final data = response.data;
      if (response.status >= 400 || (data is Map && data['error'] != null)) {
        throw Exception(
          data is Map
              ? data['error'].toString()
              : 'Não foi possível encerrar a conta.',
        );
      }

      await supabase.auth.signOut(scope: SignOutScope.local);
      if (!mounted) return;
      context.go('/login');
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message == 'Invalid login credentials'
                ? 'A senha informada está incorreta.'
                : error.message,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Card(
      color: color.withValues(alpha: .05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Zona de encerramento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isCompany
                  ? 'Primeiro desative a empresa na área administrativa. Depois disso, você poderá excluir definitivamente a conta do responsável.'
                  : 'Ao excluir sua conta, você perderá seus pontos e deixará de aparecer nas empresas das quais participa.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(
                  _loading ? 'Processando...' : 'Excluir minha conta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
