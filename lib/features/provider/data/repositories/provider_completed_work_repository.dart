import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/image_upload_codec.dart';
import '../../../../core/services/supabase_service.dart';

class ProviderCompletedWorkRepository {
  ProviderCompletedWorkRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  final SupabaseClient _client;
  static const _bucket = 'service-job-completion-images';

  Future<List<Map<String, dynamic>>> listForProvider(String providerId) async {
    final rows = await _client
        .from('provider_completed_works')
        .select('id, provider_id, executed_on, description, amount, photo_paths, created_at')
        .eq('provider_id', providerId)
        .order('executed_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<String> uploadPhoto({
    required String ownerUserId,
    required XFile image,
    required int index,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != ownerUserId) {
      throw StateError('يجب تسجيل الدخول بحساب مزود الخدمة');
    }
    final bytes = await ImageUploadCodec.fromXFile(image);
    if (bytes.isEmpty) throw StateError('الصورة فارغة');
    final path = '$ownerUserId/completed_work/${DateTime.now().microsecondsSinceEpoch}_$index.webp';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/webp'),
        );
    return path;
  }

  Future<void> removePhotos(List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(_bucket).remove(paths);
  }

  Future<Map<String, dynamic>> create({
    required String providerId,
    required DateTime executedOn,
    required String description,
    required double? amount,
    required List<String> photoPaths,
  }) async {
    final row = await _client
        .from('provider_completed_works')
        .insert({
          'provider_id': providerId,
          'executed_on': executedOn.toIso8601String().substring(0, 10),
          'description': description.trim(),
          'amount': amount,
          'photo_paths': photoPaths,
        })
        .select('id, provider_id, executed_on, description, amount, photo_paths, created_at')
        .single();
    return Map<String, dynamic>.from(row);
  }

  String imageUrl(String path) => _client.storage.from(_bucket).getPublicUrl(path);
}
