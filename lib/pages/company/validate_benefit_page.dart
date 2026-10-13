import 'package:flutter/material.dart';

import '../../services/benefit_service.dart';

class ValidateBenefitPage extends StatefulWidget {
  const ValidateBenefitPage({
    super.key,
  });

  @override
  State<ValidateBenefitPage> createState() =>
      _ValidateBenefitPageState();
}

class _ValidateBenefitPageState
    extends State<ValidateBenefitPage> {
  final BenefitService _service =
      BenefitService();

  final TextEditingController _controller =
      TextEditingController();

  bool _loading = false;
  bool _validating = false;

  String? _error;

  Future<void> _validateBenefit() async {
    final redemptionId =
        _controller.text.trim();

    if (redemptionId.isEmpty) {
      setState(() {
        _error =
            'Informe o código do benefício.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await _service.getBenefitById(
        redemptionId,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (result == null) {
        setState(() {
          _error =
              'Benefício não encontrado.';
        });

        return;
      }

      _showBenefitConfirmation(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<void> _showBenefitConfirmation(
    Map<String, dynamic> benefit,
  ) async {
    final promotion =
        benefit['promotions']
            as Map<String, dynamic>?;

    final customer =
        benefit['profiles']
            as Map<String, dynamic>?;

    final title =
        promotion?['title'] ??
            'Benefício';

    final customerName =
        customer?['full_name'] ??
            'Cliente';

    final points =
        benefit['points_spent'] ?? 0;

    final status =
        benefit['status'] ?? 'available';

    if (status != 'available') {
      setState(() {
        _error =
            status == 'used'
                ? 'Este benefício já foi utilizado.'
                : 'Este benefício não está disponível.';
      });

      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Validar benefício',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Cliente',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                customerName.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Benefício',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                title.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                '$points pontos utilizados',
              ),

              const SizedBox(height: 18),

              const Text(
                'Deseja confirmar que este benefício foi utilizado?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                await _useBenefit(
                  benefit['id'].toString(),
                );
              },
              child: const Text(
                'Confirmar utilização',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _useBenefit(
    String redemptionId,
  ) async {
    setState(() {
      _validating = true;
      _error = null;
    });

    try {
      await _service.useBenefit(
        redemptionId,
      );

      if (!mounted) return;

      setState(() {
        _validating = false;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Benefício utilizado! 🎉',
            ),
            content: const Text(
              'O benefício foi validado com sucesso.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );

      _controller.clear();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _validating = false;

        _error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Validar benefício',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 64,
            ),

            const SizedBox(height: 20),

            const Text(
              'Validar benefício do cliente',
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Informe o código do benefício apresentado pelo cliente.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 28),

            TextField(
              controller: _controller,
              decoration:
                  const InputDecoration(
                labelText:
                    'Código do benefício',
                hintText:
                    'Cole ou digite o código',
                border:
                    OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.qr_code,
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_error != null)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                margin:
                    const EdgeInsets.only(
                  bottom: 16,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.red
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  _error!,
                  style:
                      const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),

            SizedBox(
              width:
                  double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed:
                    _loading ||
                            _validating
                        ? null
                        : _validateBenefit,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.search,
                      ),
                label: Text(
                  _loading
                      ? 'Consultando...'
                      : 'Consultar benefício',
                ),
              ),
            ),

            if (_validating) ...[
              const SizedBox(height: 24),

              const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}