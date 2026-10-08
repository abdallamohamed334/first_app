import 'package:loqma/core/pickup/domain/entities/pickup_token.dart';
import 'package:loqma/core/services/supabase_service.dart';

class PickupRepository {
  final SupabaseService _supabase;

  PickupRepository(this._supabase);

  Future<PickupToken?> createPickupToken({
    required String requestId,
    required String userId,
    required String restaurantId,
  }) async {
    try {
      final rawResponse = await _supabase.client.rpc(
        'create_pickup_token',
        params: {
          'p_request_id': requestId,
          'p_user_id': userId,
          'p_restaurant_id': restaurantId,
        },
      );

      final response = _asMap(rawResponse);
      if (response == null) return null;

      final token = _string(response['token']);
      if (token == null || token.isEmpty) return null;

      // The RPC response may already contain the complete token row. Only
      // query the table when the response does not contain the required data.
      if (response['id'] != null && response['request_id'] != null) {
        return PickupToken.fromJson(response);
      }

      final tokenData = await _supabase.client
          .from('pickup_tokens')
          .select()
          .eq('token', token)
          .maybeSingle();

      if (tokenData == null) return null;
      return PickupToken.fromJson(Map<String, dynamic>.from(tokenData));
    } catch (_) {
      // Map this exception at the presentation boundary with AppErrorMapper.
      return null;
    }
  }

  Future<Map<String, dynamic>> verifyPickupToken({
    required String token,
    required String restaurantId,
  }) async {
    try {
      final rawResponse = await _supabase.client.rpc(
        'verify_pickup_token',
        params: {
          'p_token': token,
          'p_restaurant_id': restaurantId,
        },
      );

      final response = _asMap(rawResponse);
      if (response == null) {
        return _invalidResult('استجابة التحقق غير صالحة');
      }

      return {
        'isValid': _toBool(response['is_valid']),
        'userId': _string(response['user_id']),
        'requestId': _string(response['request_id']),
        'message':
            _string(response['message']) ?? 'تعذر التحقق من كود الاستلام',
      };
    } catch (_) {
      return _invalidResult('تعذر التحقق من كود الاستلام');
    }
  }

  Future<PickupToken?> getTokenByRequestId(String requestId) async {
    try {
      final response = await _supabase.client
          .from('pickup_tokens')
          .select()
          .eq('request_id', requestId)
          .maybeSingle();

      if (response == null) return null;
      return PickupToken.fromJson(Map<String, dynamic>.from(response));
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static Map<String, dynamic> _invalidResult(String message) {
    return {
      'isValid': false,
      'userId': null,
      'requestId': null,
      'message': message,
    };
  }
}
