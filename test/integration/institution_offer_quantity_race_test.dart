import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _baseUrl = (Platform.environment['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL'))
    .replaceFirst(RegExp(r'/$'), '');
final _anonKey = Platform.environment['SUPABASE_ANON_KEY'] ??
    const String.fromEnvironment('SUPABASE_ANON_KEY');

String _env(String name) => Platform.environment[name] ?? '';

final _userAToken = _env('TEST_QUANTITY_USER_A_ACCESS_TOKEN');
final _userBToken = _env('TEST_QUANTITY_USER_B_ACCESS_TOKEN');
final _institutionToken = _env('TEST_QUANTITY_INSTITUTION_ACCESS_TOKEN');
final _raceOfferId = _env('TEST_QUANTITY_RACE_OFFER_ID');
final _lifecycleOfferId = _env('TEST_QUANTITY_LIFECYCLE_OFFER_ID');

bool get _baseConfigured => _baseUrl.isNotEmpty && _anonKey.isNotEmpty;
bool get _raceConfigured =>
    _baseConfigured &&
    _userAToken.isNotEmpty &&
    _userBToken.isNotEmpty &&
    _institutionToken.isNotEmpty &&
    _raceOfferId.isNotEmpty;
bool get _lifecycleConfigured =>
    _raceConfigured && _lifecycleOfferId.isNotEmpty;

class _HttpResponse {
  const _HttpResponse(this.statusCode, this.body);

  final int statusCode;
  final dynamic body;
}

Future<_HttpResponse> _request(
  String method,
  String path, {
  String? accessToken,
  Object? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('$_baseUrl$path'),
    );
    request.headers.set('apikey', _anonKey);
    request.headers.set('Content-Type', 'application/json');
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer $accessToken');
    }
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    dynamic decoded;
    try {
      decoded = raw.isEmpty ? null : jsonDecode(raw);
    } catch (_) {
      decoded = raw;
    }
    return _HttpResponse(response.statusCode, decoded);
  } finally {
    client.close(force: true);
  }
}

Future<dynamic> _rpc(
  String name,
  Map<String, dynamic> params,
  String accessToken,
) async {
  final response = await _request(
    'POST',
    '/rest/v1/rpc/$name',
    accessToken: accessToken,
    body: params,
  );
  expect(
    response.statusCode,
    200,
    reason: '$name failed: ${response.body}',
  );
  return response.body;
}

Future<Map<String, dynamic>> _offer(String offerId, String accessToken) async {
  final response = await _request(
    'GET',
    '/rest/v1/institution_offers'
        '?select=id,quantity,remaining_quantity,reserved_quantity,status'
        '&id=eq.$offerId&limit=1',
    accessToken: accessToken,
  );
  expect(response.statusCode, 200, reason: 'offer read failed: ${response.body}');
  expect(response.body, isA<List>(), reason: 'offer response is not a list');
  final rows = response.body as List;
  expect(rows, isNotEmpty, reason: 'test offer does not exist: $offerId');
  return Map<String, dynamic>.from(rows.first as Map);
}

int _int(Map<String, dynamic> row, String key) =>
    (row[key] as num?)?.toInt() ?? -1;

String _requestId(dynamic result) {
  expect(result, isA<Map>(), reason: 'RPC result is not an object: $result');
  final id = (result as Map)['request_id']?.toString() ?? '';
  expect(id, isNotEmpty, reason: 'RPC did not return request_id: $result');
  return id;
}

Future<String> _reserve(String offerId, String token) async {
  final result = await _rpc(
    'reserve_institution_offer_safe',
    {
      'p_offer_id': offerId,
      'p_requester_id': _jwtSubject(token),
      'p_quantity': 5,
    },
    token,
  );
  expect(result, isA<Map>());
  expect((result as Map)['success'], true, reason: 'reservation failed: $result');
  return _requestId(result);
}

String _jwtSubject(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    fail('Access token is not a JWT');
  }
  final normalized = base64Url.normalize(parts[1]);
  final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
  final subject = payload['sub']?.toString() ?? '';
  if (subject.isEmpty) fail('Access token has no sub claim');
  return subject;
}

Future<void> _rejectQuietly(String requestId) async {
  try {
    await _rpc(
      'institution_update_offer_request',
      {'p_request_id': requestId, 'p_accept': false},
      _institutionToken,
    );
  } catch (_) {
    // Best-effort cleanup so a failed assertion does not leave reserved stock.
  }
}

Future<void> _assertOffer(
  String offerId, {
  required int quantity,
  required int remaining,
  required int reserved,
}) async {
  final row = await _offer(offerId, _institutionToken);
  expect(_int(row, 'quantity'), quantity);
  expect(_int(row, 'remaining_quantity'), remaining);
  expect(_int(row, 'reserved_quantity'), reserved);
  expect(_int(row, 'remaining_quantity'), greaterThanOrEqualTo(0));
  expect(_int(row, 'reserved_quantity'), greaterThanOrEqualTo(0));
  expect(
    _int(row, 'remaining_quantity') + _int(row, 'reserved_quantity'),
    lessThanOrEqualTo(_int(row, 'quantity')),
  );
}

void main() {
  group('Institution offer quantity race condition', () {
    test(
      'two concurrent requests reserve exactly 10 and rejected requests restore exactly once',
      () async {
        await _assertOffer(
          _raceOfferId,
          quantity: 20,
          remaining: 20,
          reserved: 0,
        );

        String? requestA;
        String? requestB;
        try {
          final results = await Future.wait([
            _reserve(_raceOfferId, _userAToken),
            _reserve(_raceOfferId, _userBToken),
          ]);
          requestA = results[0];
          requestB = results[1];

          await _assertOffer(
            _raceOfferId,
            quantity: 20,
            remaining: 10,
            reserved: 10,
          );

          await Future.wait([
            _rejectQuietly(requestA),
            _rejectQuietly(requestB),
          ]);

          await _assertOffer(
            _raceOfferId,
            quantity: 20,
            remaining: 20,
            reserved: 0,
          );
        } finally {
          // If the test fails before the rejection phase, release any pending
          // reservations that were created by this run.
          if (requestA != null) await _rejectQuietly(requestA);
          if (requestB != null) await _rejectQuietly(requestB);
        }
      },
      skip: _raceConfigured
          ? null
          : 'Set the quantity-race Supabase tokens and TEST_QUANTITY_RACE_OFFER_ID',
    );

    test(
      'reject one request and complete the other leaves 15 of the original 20 available',
      () async {
        await _assertOffer(
          _lifecycleOfferId,
          quantity: 20,
          remaining: 20,
          reserved: 0,
        );

        final requestIds = await Future.wait([
          _reserve(_lifecycleOfferId, _userAToken),
          _reserve(_lifecycleOfferId, _userBToken),
        ]);

        await _assertOffer(
          _lifecycleOfferId,
          quantity: 20,
          remaining: 10,
          reserved: 10,
        );

        await _rpc(
          'institution_update_offer_request',
          {'p_request_id': requestIds[0], 'p_accept': false},
          _institutionToken,
        );
        await _assertOffer(
          _lifecycleOfferId,
          quantity: 20,
          remaining: 15,
          reserved: 5,
        );

        final accepted = await _rpc(
          'institution_update_offer_request',
          {'p_request_id': requestIds[1], 'p_accept': true},
          _institutionToken,
        );
        expect((accepted as Map)['status'], 'accepted');

        final ready = await _rpc(
          'institution_mark_offer_request_ready',
          {'p_request_id': requestIds[1]},
          _institutionToken,
        );
        expect((ready as Map)['status'], 'ready_for_pickup');

        final codeResult = await _rpc(
          'user_generate_pickup_code',
          {'p_request_id': requestIds[1]},
          _userBToken,
        );
        final code = (codeResult as Map)['pickup_code']?.toString() ?? '';
        expect(code, hasLength(6));

        final pickedUp = await _rpc(
          'institution_verify_offer_request_pickup_code',
          {'p_request_id': requestIds[1], 'p_code': code},
          _institutionToken,
        );
        expect((pickedUp as Map)['status'], 'picked_up');

        final completed = await _rpc(
          'institution_complete_offer_request',
          {'p_request_id': requestIds[1]},
          _institutionToken,
        );
        expect((completed as Map)['status'], 'completed');

        // The rejected 5 returned; the completed 5 stayed consumed.
        await _assertOffer(
          _lifecycleOfferId,
          quantity: 20,
          remaining: 15,
          reserved: 5,
        );
      },
      skip: _lifecycleConfigured
          ? null
          : 'Set TEST_QUANTITY_LIFECYCLE_OFFER_ID to run the disposable full-lifecycle fixture',
    );
  });
}
