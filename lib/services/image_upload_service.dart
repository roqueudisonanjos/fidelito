import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const int maxVideoBytes = 15 * 1024 * 1024;
  static const int maxMediaCount = 5;

  Future<List<String>> pickAndUploadMultiple({
    required String folder,
    required String filePrefix,
    int maxCount = maxMediaCount,
  }) async {
    final picked = await _picker.pickMultipleMedia(
      limit: maxCount,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return [];
    if (picked.length > maxMediaCount) {
      throw Exception('Selecione no máximo 5 mídias.');
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final prepared = <({Uint8List bytes, String mime, String extension})>[];
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? '';
      final isVideo = mime.startsWith('video/') ||
          RegExp(r'\.(mp4|mov|m4v|webm)$', caseSensitive: false).hasMatch(file.name);
      final maxBytes = isVideo ? maxVideoBytes : maxImageBytes;
      if (bytes.length > maxBytes) {
        final limit = isVideo ? '15 MB' : '5 MB';
        throw Exception('${file.name} ultrapassa o limite de $limit.');
      }
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : (isVideo ? 'mp4' : 'jpg');
      prepared.add((bytes: bytes, mime: mime, extension: extension));
    }

    final urls = <String>[];
    for (final media in prepared) {
      final path = '$folder/${user.id}/$filePrefix-${DateTime.now().microsecondsSinceEpoch}-${urls.length}.${media.extension}';
      await _client.storage.from('fidelito-images').uploadBinary(
        path,
        media.bytes,
        fileOptions: FileOptions(upsert: true, contentType: media.mime.isNotEmpty ? media.mime : _contentType(media.extension)),
      );
      urls.add(_client.storage.from('fidelito-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<String?> pickAndUpload({
    required String folder,
    required String filePrefix,
    BuildContext? cropContext,
    double? cropAspectRatio,
  }) async {
    // Read theme values before awaiting the gallery picker, so this context is
    // not accessed across an asynchronous gap.
    final Color? cropSurfaceColor = cropContext == null
        ? null
        : Theme.of(cropContext).colorScheme.surface;
    final Color? cropOnSurfaceColor = cropContext == null
        ? null
        : Theme.of(cropContext).colorScheme.onSurface;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null) return null;

    Uint8List bytes;
    String extension;

    if (cropAspectRatio != null) {
      if (cropContext == null) {
        throw ArgumentError('É necessário informar o contexto para recortar a imagem.');
      }
      if (!cropContext.mounted) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: CropAspectRatio(
          ratioX: cropAspectRatio,
          ratioY: 1,
        ),
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar imagem',
            toolbarColor: cropSurfaceColor!,
            toolbarWidgetColor: cropOnSurfaceColor!,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Ajustar imagem',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(
            context: cropContext,
            presentStyle: WebPresentStyle.dialog,
            size: _webCropperSize(cropContext),
            minContainerWidth: 240,
            minContainerHeight: 180,
            customDialogBuilder: (cropper, initCropper, crop, rotate, scale) {
              return _PlimWebCropDialog(
                cropper: cropper,
                initCropper: initCropper,
                crop: crop,
                rotate: rotate,
              );
            },
            translations: const WebTranslations(
              title: 'Ajustar imagem',
              rotateLeftTooltip: 'Girar para a esquerda',
              rotateRightTooltip: 'Girar para a direita',
              cancelButton: 'Cancelar',
              cropButton: 'Cortar',
            ),
          ),
        ],
      );

      // Fechar o editor sem confirmar mantém a imagem anterior.
      if (cropped == null) return null;
      bytes = await cropped.readAsBytes();
      extension = 'jpg';
    } else {
      bytes = await picked.readAsBytes();
      extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final path =
        '$folder/${user.id}/$filePrefix-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('fidelito-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentType(extension),
          ),
        );
    return _client.storage.from('fidelito-images').getPublicUrl(path);
  }

  CropperSize _webCropperSize(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 600;

    if (isCompact) {
      // Keep the crop area compact on phones so the action buttons fit
      // within the visible dialog instead of requiring page scrolling.
      final width = (screen.width - 32).clamp(280.0, 380.0).round();
      final height = (screen.height * 0.34).clamp(220.0, 300.0).round();
      return CropperSize(width: width, height: height);
    }

    final width = (screen.width * 0.65).clamp(480.0, 620.0).round();
    final height = (screen.height * 0.55).clamp(380.0, 520.0).round();
    return CropperSize(width: width, height: height);
  }


  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
      case 'm4v':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'image/jpeg';
    }
  }
}


/// Dialog Web próprio do Plim. O Cropper fornece a área de edição,
/// enquanto os botões e a confirmação ficam sob controle da aplicação.
class _PlimWebCropDialog extends StatefulWidget {
  final Widget cropper;
  final void Function() initCropper;
  final Future<String?> Function() crop;
  final void Function(RotationAngle) rotate;

  const _PlimWebCropDialog({
    required this.cropper,
    required this.initCropper,
    required this.crop,
    required this.rotate,
  });

  @override
  State<_PlimWebCropDialog> createState() => _PlimWebCropDialogState();
}

class _PlimWebCropDialogState extends State<_PlimWebCropDialog> {
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
  }

  Future<void> _confirmCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    try {
      final result = await widget.crop();
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _isCropping = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCropping = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 600;
    final cropHeight = (screen.height * (compact ? 0.34 : 0.55))
        .clamp(compact ? 220.0 : 320.0, compact ? 300.0 : 520.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 420 : 680),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajustar imagem',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Girar para a esquerda',
                    onPressed: _isCropping
                        ? null
                        : () => widget.rotate(RotationAngle.counterClockwise90),
                    icon: const Icon(Icons.rotate_left),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  IconButton(
                    tooltip: 'Girar para a direita',
                    onPressed: _isCropping
                        ? null
                        : () => widget.rotate(RotationAngle.clockwise90),
                    icon: const Icon(Icons.rotate_right),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: cropHeight,
                width: double.infinity,
                child: ClipRect(child: widget.cropper),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCropping ? null : _confirmCrop,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: _isCropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cortar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
