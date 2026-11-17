import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUpload({
    required String folder,
    required String filePrefix,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (picked == null) return null;
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
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

  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
