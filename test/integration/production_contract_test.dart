import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _baseUrl = (Platform.environment['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL'))
    .replaceFirst(RegExp(r'/$'), '');
final _anonKey = Platform.environment['SUPABASE_ANON_KEY'] ??
    const String.fromEnvironment('SUPABASE_ANON_KEY');

bool get _configured => _baseUrl.isNotEmpty && _anonKey.isNotEmpty;
String _env(String name) => Platform.environment[name] ?? '';

Future<HttpResponse> _request(
  String method,
  String path, {
  Object? body,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse('$_baseUrl$path'));
    request.headers.set('apikey', _anonKey);
    request.headers.set('Content-Type', 'application/json');
    headers.forEach((name, value) => request.headers.set(name, value));
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    return HttpResponse(
      response.statusCode,
      jsonDecode(await response.transform(utf8.decoder).join()),
    );
  } finally {
    client.close(force: true);
  }
}

class HttpResponse {
  const HttpResponse(this.statusCode, this.body);
  final int statusCode;
  final dynamic body;
}

void main() {
  final skipReason = _configured ? null : 'Set SUPABASE_URL and SUPABASE_ANON_KEY for Production contract tests';

  group('Production edge contracts', () {
    test('send-otp rejects malformed phone before sending', () async {
      final response = await _request(
        'POST',
        '/functions/v1/send-otp',
        body: const {'phone': 'invalid', 'loginMode': 'user'},
      );
      expect(response.statusCode, 400);
    }, skip: skipReason);

    test('verify-otp rejects calls without the internal secret', () async {
      final response = await _request(
        'POST',
        '/functions/v1/verify-otp',
        body: const {'phone': '01000000000', 'code': '000000'},
      );
      expect(response.statusCode, 401);
    }, skip: skipReason);

    test('anonymous provider discovery does not expose contact fields', () async {
      final response = await _request(
        'GET',
        '/rest/v1/published_service_providers?select=id,display_name,phone,whatsapp,email,address,branches,total_jobs,response_time_minutes&limit=5',
      );
      expect(response.statusCode, 200);
      if (response.body is List) {
        for (final row in response.body as List) {
          expect(row['phone'], isNull);
          expect(row['whatsapp'], isNull);
          expect(row['email'], isNull);
          expect(row['address'], isNull);
          expect(row['branches'], isNull);
          expect(row['total_jobs'], isNull);
          expect(row['response_time_minutes'], isNull);
        }
      }
    }, skip: skipReason);

    test('unauthenticated invalid image upload is rejected', () async {
      final response = await _request(
        'POST',
        '/storage/v1/object/charity-images/automated-invalid.txt',
        body: const {'not': 'an image'},
        headers: const {'Content-Type': 'text/plain'},
      );
      expect(response.statusCode, isNot(200));
    }, skip: skipReason);

    test('push notification endpoint rejects missing internal secret', () async {
      final response = await _request(
        'POST',
        '/functions/v1/send-push-notification',
        body: const {'userId': '00000000-0000-0000-0000-000000000000', 'title': 'test', 'body': 'test'},
      );
      expect(response.statusCode, 401);
    }, skip: skipReason);
  });

  group('Authenticated contract tests', () {
    final userToken = _env('TEST_USER_ACCESS_TOKEN');
    final providerToken = _env('TEST_PROVIDER_ACCESS_TOKEN');
    final institutionToken = _env('TEST_INSTITUTION_ACCESS_TOKEN');

    test('user session refresh succeeds with a supplied refresh token', () async {
      final refreshToken = _env('TEST_REFRESH_TOKEN');
      expect(refreshToken, isNotEmpty);
      final response = await _request(
        'POST',
        '/auth/v1/token?grant_type=refresh_token',
        body: {'refresh_token': refreshToken},
      );
      expect(response.statusCode, 200);
      expect(response.body['access_token'], isNotEmpty);
    }, skip: userToken.isEmpty ? 'Set TEST_REFRESH_TOKEN for session refresh' : null);

    test('user/provider/institution tokens are available for RLS suite', () {
      expect(userToken, isNotEmpty);
      expect(providerToken, isNotEmpty);
      expect(institutionToken, isNotEmpty);
    }, skip: (userToken.isNotEmpty && providerToken.isNotEmpty && institutionToken.isNotEmpty)
        ? null
        : 'Set TEST_USER_ACCESS_TOKEN, TEST_PROVIDER_ACCESS_TOKEN and TEST_INSTITUTION_ACCESS_TOKEN');
  });
}
