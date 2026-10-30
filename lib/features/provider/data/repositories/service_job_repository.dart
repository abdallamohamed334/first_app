import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/image_upload_codec.dart';
import '../../../../core/services/supabase_service.dart';

class ServiceJobRepository {
  ServiceJobRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> acceptedRequests(String providerId) async {
    await _expirePending();
    final rows = await _client
        .from('service_requests')
        .select('id, title, description, city, address, status, created_at, completed_at, accepted_provider_id')
        .eq('accepted_provider_id', providerId)
        .inFilter('status', ['in_progress', 'completed'])
        .order('updated_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> providerCompletions(String providerId) async {
    await _expirePending();
    final rows = await _client
        .from('service_job_completions')
        .select('id, request_id, provider_id, executed_on, description, photo_urls, status, photos_hidden, confirmation_deadline, confirmed_at, created_at')
        .eq('provider_id', providerId)
        .order('executed_on', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> publicCompletions(String providerId) async {
    await _expirePending();
    final rows = await _client
        .from('service_job_completions')
        .select('id, provider_id, executed_on, description, photo_urls, status, photos_hidden, confirmed_at')
        .eq('provider_id', providerId)
        .inFilter('status', ['confirmed', 'unconfirmed'])
        .order('executed_on', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> completion(String completionId) async {
    final row = await _client
        .from('service_job_completions')
        .select('id, provider_id, client_id, request_id, status, executed_on, description, photo_urls')
        .eq('id', completionId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<String> uploadPhoto({
    required String requestId,
    required XFile image,
    required int index,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول أولًا');
    final bytes = await ImageUploadCodec.fromXFile(image);
    if (bytes.isEmpty) throw StateError('الصورة فارغة');
    final path = '${user.id}/$requestId/${DateTime.now().microsecondsSinceEpoch}_$index.webp';
    await _client.storage.from('service-job-completion-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/webp'),
        );
    return path;
  }

  String imageUrl(String path) =>
      _client.storage.from('service-job-completion-images').getPublicUrl(path);

  Future<String> submitCompletion({
    required String requestId,
    required DateTime executedOn,
    required String description,
    required List<String> photoPaths,
  }) async {
    final result = await _client.rpc(
      'submit_service_job_completion',
      params: {
        'p_request_id': requestId,
        'p_executed_on': executedOn.toIso8601String().substring(0, 10),
        'p_description': description.trim(),
        'p_photo_urls': photoPaths,
      },
    );
    return result.toString();
  }

  Future<void> requestAction({
    required String completionId,
    required String actionType,
    String? reason,
  }) async {
    await _client.rpc(
      'request_service_job_action',
      params: {
        'p_completion_id': completionId,
        'p_action_type': actionType,
        'p_reason': reason,
      },
    );
  }

  Future<void> _expirePending() async {
    try {
      await _client.rpc('expire_service_job_completions');
    } catch (error) {
      debugPrint('[ServiceJob] expiry refresh skipped: $error');
    }
  }
}
