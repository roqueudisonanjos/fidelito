import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._();

  static const String appUrl = 'https://plim.web.app';
  static const String _logoAsset = 'assets/images/plim_logo.png';

  static Future<void> shareApp() async {
    const message =
        '✨ Conheça o Plim! Descubra empresas, acumule pontos e troque por '
        'recompensas especiais. Compartilhe essa novidade com seus amigos!\n\n'
        'Acesse: $appUrl';

    final logo = await _loadBrandLogo();
    await _shareWithImage(
      text: message,
      subject: 'Conheça o Plim',
      image: logo,
    );
  }

  /// Compartilhamento do clube de fidelidade pela própria empresa.
  /// Usa a foto/logo da empresa e recorre à marca do Plim quando ausente.
  static Future<void> shareCompanyClub({
    required String companyName,
    String? companyLogoUrl,
    String? companyId,
  }) async {
    final name = companyName.trim().isEmpty ? 'nossa empresa' : companyName.trim();
    final companyLink = companyId?.trim().isNotEmpty == true
        ? '$appUrl/#/empresa/${companyId!.trim()}'
        : appUrl;
    final message =
        '💚 Entre no clube de fidelidade de $name e tenha acesso a ofertas '
        'exclusivas, benefícios especiais e recompensas!\n\n'
        'Faça parte do nosso clube pelo Plim: $companyLink';

    final image = await _loadCompanyLogo(companyLogoUrl) ??
        await _loadBrandLogo();

    await _shareWithImage(
      text: message,
      subject: 'Clube de fidelidade de $name',
      image: image,
    );
  }

  static Future<void> shareOffer({
    required String companyName,
    required String title,
    String? description,
    String? companyLogoUrl,
    String? companyId,
    String? offerId,
  }) async {
    final extra = description?.trim().isNotEmpty == true ? '\n${description!.trim()}' : '';
    final offerQuery = offerId?.trim().isNotEmpty == true
        ? '?oferta=${Uri.encodeComponent(offerId!.trim())}'
        : '';
    final companyLink = offerId?.trim().isNotEmpty == true
        ? '$appUrl/#/oferta/${Uri.encodeComponent(offerId!.trim())}'
        : (companyId?.trim().isNotEmpty == true
            ? '$appUrl/#/empresa/${companyId!.trim()}$offerQuery'
            : appUrl);
    final message = '📣 Oferta de $companyName!\n\n$title$extra\n\nConfira no Plim: $companyLink';
    final image = await _loadCompanyLogo(companyLogoUrl) ?? await _loadBrandLogo();
    await _shareWithImage(text: message, subject: 'Oferta de $companyName', image: image);
  }


  static Future<void> sharePromotion({
    required String companyName,
    required String title,
    required String type,
    String? discountPercentage,
    String? giftDescription,
    String? description,
    String? companyLogoUrl,
    String? companyId,
  }) async {
    final companyLink = companyId?.trim().isNotEmpty == true
        ? '$appUrl/#/empresa/${companyId!.trim()}'
        : appUrl;
    final benefit = type == 'discount' &&
            discountPercentage != null &&
            discountPercentage.trim().isNotEmpty
        ? '${discountPercentage.trim()}% de desconto'
        : (giftDescription?.trim().isNotEmpty == true
              ? giftDescription!.trim()
              : 'uma recompensa especial');

    final extraDescription = description?.trim().isNotEmpty == true
        ? '\n${description!.trim()}'
        : '';

    final message =
        '🎁 Aproveite esta recompensa oferecida por $companyName!\n\n'
        '$title\n$benefit$extraDescription\n\n'
        'Veja essa e outras oportunidades no Plim: $companyLink';

    final image = await _loadCompanyLogo(companyLogoUrl) ??
        await _loadBrandLogo();

    await _shareWithImage(
      text: message,
      subject: 'Recompensa de $companyName',
      image: image,
    );
  }

  static Future<_ShareImage> _loadBrandLogo() async {
    final data = await rootBundle.load(_logoAsset);
    return _ShareImage(
      bytes: data.buffer.asUint8List(),
      mimeType: 'image/png',
      fileName: 'plim.png',
    );
  }

  static Future<_ShareImage?> _loadCompanyLogo(String? url) async {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;

    try {
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (response.bodyBytes.isEmpty) return null;

      final contentType = (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      const supportedTypes = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/webp': 'webp',
        'image/gif': 'gif',
      };
      final extension = supportedTypes[contentType];
      if (extension == null) return null;

      return _ShareImage(
        bytes: response.bodyBytes,
        mimeType: contentType,
        fileName: 'logo-empresa.$extension',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _shareWithImage({
    required String text,
    required String subject,
    required _ShareImage image,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          title: subject,
          downloadFallbackEnabled: false,
          files: [
            XFile.fromData(
              image.bytes,
              mimeType: image.mimeType,
              name: image.fileName,
            ),
          ],
          fileNameOverrides: [image.fileName],
        ),
      );
    } catch (_) {
      // Alguns navegadores ou destinos não aceitam anexos. Nesse caso,
      // mantém o compartilhamento disponível somente com o texto e o link.
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, title: subject),
      );
    }
  }
}

class _ShareImage {
  const _ShareImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}
