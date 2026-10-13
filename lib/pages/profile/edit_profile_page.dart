import 'package:flutter/material.dart';

import '../../services/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
  });

  @override
  State<EditProfilePage> createState() =>
      _EditProfilePageState();
}

class _EditProfilePageState
    extends State<EditProfilePage> {
  final ProfileService _service =
      ProfileService();

  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _whatsappController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();

    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await _service.getProfile();

      if (!mounted) return;

      _nameController.text =
          profile?['full_name']?.toString() ?? '';

      _whatsappController.text =
          _formatWhatsapp(
        profile?['whatsapp']?.toString() ?? '',
      );

      setState(() {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _service.updateProfile(
        fullName: _nameController.text,
        whatsapp: _whatsappController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Dados atualizados com sucesso!',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _formatWhatsapp(String value) {
    final numbers =
        value.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (numbers.length <= 2) {
      return numbers;
    }

    if (numbers.length <= 7) {
      return '(${numbers.substring(0, 2)}) '
          '${numbers.substring(2)}';
    }

    if (numbers.length <= 11) {
      return '(${numbers.substring(0, 2)}) '
          '${numbers.substring(2, 7)}-'
          '${numbers.substring(7)}';
    }

    return numbers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dados cadastrais',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
              ),

              const SizedBox(height: 16),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });

                  _loadProfile();
                },
                child: const Text(
                  'Tentar novamente',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Seus dados',
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Mantenha seus dados cadastrais atualizados.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 28),

            TextFormField(
              controller:
                  _nameController,
              textInputAction:
                  TextInputAction.next,
              decoration:
                  const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon:
                    Icon(Icons.person_outline),
                border:
                    OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Informe seu nome.';
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller:
                  _whatsappController,
              keyboardType:
                  TextInputType.phone,
              decoration:
                  const InputDecoration(
                labelText: 'WhatsApp',
                hintText:
                    '(94) 99123-4567',
                prefixIcon:
                    Icon(Icons.phone),
                border:
                    OutlineInputBorder(),
              ),
              validator: (value) {
                final numbers =
                    value?.replaceAll(
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

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Salvar alterações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}