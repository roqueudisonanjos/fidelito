import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../services/qr_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final QrService _qrService = QrService();

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
      final result = await _qrService.redeemQrCode(code);

      if (!mounted) return;

      final isPendingRequest = result['request_pending'] == true;
      final points = result['points'] ?? result['points_earned'];
      final companyName = result['company_name']?.toString() ?? 'empresa';
      final alreadyPending = result['already_pending'] == true;
      final balance = result['new_balance'];

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(isPendingRequest ? 'Solicitação enviada! 🎉' : 'Pontos recebidos! 🎉'),
            content: Text(
              isPendingRequest
                  ? (alreadyPending
                      ? 'Sua solicitação de $points pontos para o programa de fidelidade da $companyName já está aguardando aprovação da empresa.\n\nVocê poderá escanear novamente após esta solicitação ser analisada.'
                      : 'Você solicitou $points pontos no programa de fidelidade da $companyName.\n\nA empresa precisa aprovar a solicitação antes que os pontos sejam adicionados ao seu saldo. Você receberá uma notificação quando houver uma decisão.')
                  : 'Você ganhou $points pontos.\n\nSeu novo saldo é $balance pontos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      context.pop(true);
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
      appBar: AppBar(title: const Text('Escanear QR Code')),
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

              debugPrint('QR CODE LIDO: $value');

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
                    'Aponte a câmera para o QR Code',
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
                      'Validando QR Code...',
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
