import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/benefit_service.dart';

class BenefitScannerPage extends StatefulWidget {
  const BenefitScannerPage({super.key});

  @override
  State<BenefitScannerPage> createState() => _BenefitScannerPageState();
}

class _BenefitScannerPageState extends State<BenefitScannerPage> {
  final BenefitService _service = BenefitService();

  bool _processing = false;

  String? _error;

  Future<void> _processQr(String code) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final result = await _service.validateBenefit(code);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),

            title: const Text('Recompensa validada!'),

            content: Text(
              '${result['title']}\n\n'
              'Pontos utilizados: '
              '${result['points_spent']}\n\n'
              'A recompensa foi marcada como utilizado.',
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processing = false;

        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validar recompensa')),

      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_processing) {
                return;
              }

              if (capture.barcodes.isEmpty) {
                return;
              }

              final barcode = capture.barcodes.first;

              final value = barcode.rawValue;

              if (value == null || value.isEmpty) {
                return;
              }

              _processQr(value);
            },
          ),

          Center(
            child: Container(
              width: 280,
              height: 280,

              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),

                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 40,

            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(16),

                    margin: const EdgeInsets.only(bottom: 16),

                    decoration: BoxDecoration(
                      color: Colors.black87,

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,

                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.black54,

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Text(
                    'Aponte a câmera para o QR Code da recompensa',
                    textAlign: TextAlign.center,

                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          if (_processing)
            Container(
              color: Colors.black54,

              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    CircularProgressIndicator(),

                    SizedBox(height: 16),

                    Text(
                      'Validanda recompensa...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
