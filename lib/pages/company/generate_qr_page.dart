import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/qr_code.dart';
import '../../services/qr_service.dart';
import '../../services/qr_print_service.dart';

class GenerateQrPage extends StatefulWidget {
  const GenerateQrPage({super.key});

  @override
  State<GenerateQrPage> createState() => _GenerateQrPageState();
}


class _GenerateQrPageState extends State<GenerateQrPage> {
  final QrService _qrService = QrService();
  final TextEditingController _pointsController = TextEditingController(text: '10');
  QrCodeModel? _qrCode;
  bool _staticMode = false;
  bool _loading = false;
  bool _printing = false;
  String? _error;
  String _companyName = 'Empresa';
  String? _companyLogoUrl;
  Timer? _expirationTimer;


  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final company = await Supabase.instance.client
          .from('companies')
          .select('name, logo_url')
          .eq('owner_id', user.id)
          .eq('active', true)
          .maybeSingle();
      if (!mounted || company == null) return;
      setState(() {
        _companyName = company['name']?.toString() ?? 'Empresa';
        _companyLogoUrl = company['logo_url']?.toString();
      });
    } catch (_) {}
  }


  Future<void> _generateQr() async {
    final points = int.tryParse(_pointsController.text.trim());
    if (points == null || points <= 0) {
      setState(() => _error = 'Informe uma quantidade válida de pontos.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final qr = _staticMode
          ? await _qrService.createStaticQrCode(points: points)
          : await _qrService.createQrCode(points: points, expirationMinutes: 10);
      if (!mounted) return;
      setState(() { _qrCode = qr; _loading = false; });
      _expirationTimer?.cancel();
      if (!_staticMode) {
        _expirationTimer = Timer(const Duration(minutes: 10), () {
          if (!mounted) return;
          setState(() => _qrCode = null);
        });
      }
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
    setState(() { _qrCode = null; _error = null; });
  }


  Future<void> _copyManualCode() async {
    if (_qrCode == null) return;
    await Clipboard.setData(ClipboardData(text: _qrCode!.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código de validação copiado.')),
    );
  }

  Future<void> _shareManualCode() async {
    if (_qrCode == null) return;
    final qr = _qrCode!;
    await SharePlus.instance.share(ShareParams(
      text: 'Código Fidelito para receber ${qr.points} pontos na fidelidade de $_companyName: ${qr.code}',
    ));
  }

  Future<void> _printQr() async {
    if (_qrCode == null || !_qrCode!.isStatic || _printing) return;
    setState(() => _printing = true);
    try {
      await QrPrintService.printOrSaveQr(
        code: _qrCode!.code,
        points: _qrCode!.points,
        companyName: _companyName,
        companyLogoUrl: _companyLogoUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível preparar o QR para impressão: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/company')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _qrCode == null ? _buildForm() : _buildQr(),
          ),
        ),
      ),
    );
  }


  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2, size: 72),
          const SizedBox(height: 18),
          const Text('Gerar QR Code', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Escolha como o código será utilizado.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.timer_outlined), label: Text('Temporário')),
              ButtonSegment(value: true, icon: Icon(Icons.print_outlined), label: Text('Para imprimir')),
            ],
            selected: {_staticMode},
            onSelectionChanged: _loading ? null : (selection) => setState(() => _staticMode = selection.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _staticMode
                    ? 'QR permanente: pode ser impresso e escaneado por vários clientes. O código continuará ativo até ser desativado pela empresa ou pelo sistema.'
                    : 'QR temporário: válido por 10 minutos e pode ser utilizado apenas uma vez.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantidade de pontos', prefixIcon: Icon(Icons.stars), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _generateQr,
              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_staticMode ? 'Gerar QR para impressão' : 'Gerar QR Code'),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQr() {
    final qr = _qrCode!;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(qr.isStatic ? 'QR Code permanente' : 'QR Code temporário', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${qr.points} pontos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: qr.code, size: 250),
          ),
          const SizedBox(height: 16),
          Text(qr.isStatic ? 'Este QR pode ser impresso e usado por vários clientes.' : 'Peça para o cliente escanear o código.', textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(qr.isStatic ? 'Permanecerá ativo até ser desativado.' : 'Válido por 10 minutos e uso único.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          SelectableText(
            qr.code,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyManualCode,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareManualCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartilhar'),
                ),
              ),
            ],
          ),
          if (qr.isStatic) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _printing ? null : _printQr,
                icon: _printing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
                label: Text(_printing ? 'Preparando arquivo...' : 'Baixar / imprimir QR Code'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Será aberto o diálogo de impressão, onde você pode imprimir ou salvar em PDF.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _newQr, child: const Text('Gerar outro QR Code')),
        ],
      ),
    );
  }
}
