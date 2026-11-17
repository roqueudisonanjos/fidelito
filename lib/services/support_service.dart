import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';

class SupportService {
  static Future<void> openWhatsApp(BuildContext context) async {
    const message = 'Preciso de ajuda';
    final number = AppConfig.supportWhatsappNumber.replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure o WhatsApp profissional da ApoloApps para disponibilizar o suporte.',
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}
