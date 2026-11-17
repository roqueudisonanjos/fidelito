import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';

class ChangePasswordSection extends StatefulWidget {
  const ChangePasswordSection({super.key});

  @override
  State<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _expanded = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _showMessage('Não foi possível identificar sua conta. Entre novamente.');
      return;
    }

    setState(() => _saving = true);
    try {
      // O Supabase valida a senha atual no próprio pedido de atualização.
      await client.auth.updateUser(
        UserAttributes(
          password: _newPassword.text,
          currentPassword: _currentPassword.text,
        ),
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _expanded = false);
      _showMessage('Senha atualizada com sucesso.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(
        e.message.toLowerCase().contains('invalid')
            ? 'A senha atual está incorreta.'
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Não foi possível atualizar a senha. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 24),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            ),
            title: const Text(
              'Segurança da conta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Atualize sua senha de acesso.'),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: !_showCurrent,
                    decoration: InputDecoration(
                      labelText: 'Senha atual',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showCurrent = !_showCurrent),
                        icon: Icon(
                          _showCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe sua senha atual.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: !_showNew,
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      helperText: 'Use pelo menos 8 caracteres.',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showNew = !_showNew),
                        icon: Icon(
                          _showNew ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'A nova senha deve ter pelo menos 8 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: !_showConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirme a nova senha',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        icon: Icon(
                          _showConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) => value != _newPassword.text
                        ? 'As senhas não coincidem.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _changePassword,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'Atualizando...' : 'Atualizar senha',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
