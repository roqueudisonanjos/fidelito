import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/qr_code.dart';
import '../../services/qr_service.dart';
import 'package:go_router/go_router.dart';

class GenerateQrPage extends StatefulWidget {
  const GenerateQrPage({super.key});

  @override
  State<GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends State<GenerateQrPage> {
  final QrService _qrService = QrService();

  final TextEditingController _pointsController = TextEditingController(
    text: '10',
  );

  QrCodeModel? _qrCode;

  bool _loading = false;

  String? _error;

  Timer? _expirationTimer;

  Future<void> _generateQr() async {
    final points = int.tryParse(_pointsController.text.trim());

    if (points == null || points <= 0) {
      setState(() {
        _error = 'Informe uma quantidade válida de pontos.';
      });

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final qr = await _qrService.createQrCode(
        points: points,
        expirationMinutes: 10,
      );

      if (!mounted) return;

      setState(() {
        _qrCode = qr;
        _loading = false;
      });

      _expirationTimer?.cancel();

      _expirationTimer = Timer(const Duration(minutes: 10), () {
        if (!mounted) return;

        setState(() {
          _qrCode = null;
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _newQr() {
    _expirationTimer?.cancel();

    setState(() {
      _qrCode = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/company');
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _qrCode == null ? _buildForm() : _buildQr(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2, size: 80),

        const SizedBox(height: 24),

        const Text(
          'Gerar QR Code',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        const Text(
          'Informe quantos pontos o cliente receberá.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        TextField(
          controller: _pointsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade de pontos',
            prefixIcon: Icon(Icons.stars),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _generateQr,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gerar QR Code'),
          ),
        ),
      ],
    );
  }

  Widget _buildQr() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'QR Code gerado',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          '${_qrCode!.points} pontos',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(data: _qrCode!.code, size: 280),
        ),

        const SizedBox(height: 20),

        const Text(
          'Peça para o cliente escanear este código.',
          textAlign: TextAlign.center,
        ),

        const Text(
          'Este código é válido por 10 minutos e pode ser usado apenas uma vez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),

        OutlinedButton(
          onPressed: _newQr,
          child: const Text('Gerar outro QR Code'),
        ),
      ],
    );
  }
}
