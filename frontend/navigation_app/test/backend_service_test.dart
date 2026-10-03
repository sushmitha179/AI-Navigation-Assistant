import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navigation_app/services/backend_service.dart';

void main() {
  group('BackendService response validation', () {
    test('readSign posts one image to the dedicated endpoint', () async {
      final backend = BackendService(
        baseUrl: 'http://test.local',
        client: MockClient((request) async {
          expect(request.url.path, '/read-sign');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'text': 'EXIT 24 HOURS',
              'confidence': 0.91,
              'word_count': 3,
            }),
            200,
          );
        }),
      );

      final result = await backend.readSign(Uint8List.fromList([1, 2, 3]));

      expect(result.text, 'EXIT 24 HOURS');
      expect(result.confidence, 0.91);
      expect(result.wordCount, 3);
      await backend.disconnect();
    });

    test('rejects null action instead of defaulting to CONTINUE', () async {
      final backend = BackendService(
        baseUrl: 'http://test.local',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'action': null,
                'reason': 'No decision available',
                'priority': 'LOW',
                'detections': [],
              }),
              200,
            )),
      );

      await expectLater(
        backend.processFrame(Uint8List.fromList([1, 2, 3])),
        throwsA(
          predicate((error) =>
              error is Exception &&
              error.toString().contains('unsupported action')),
        ),
      );
      await backend.disconnect();
    });

    test('rejects unknown navigation actions', () async {
      final backend = BackendService(
        baseUrl: 'http://test.local',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'action': 'PROCEED SAFELY',
                'reason': 'unknown action',
                'priority': 'LOW',
                'detections': [],
              }),
              200,
            )),
      );

      await expectLater(
        backend.processFrame(Uint8List.fromList([1, 2, 3])),
        throwsA(
          predicate((error) =>
              error is Exception &&
              error.toString().contains('unsupported action')),
        ),
      );
      await backend.disconnect();
    });

    test('rejects malformed entries in the detections list', () async {
      final backend = BackendService(
        baseUrl: 'http://test.local',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'action': 'CONTINUE',
                'reason': 'No detected obstacles',
                'priority': 'LOW',
                'detections': ['malformed detection'],
              }),
              200,
            )),
      );

      await expectLater(
        backend.processFrame(Uint8List.fromList([1, 2, 3])),
        throwsA(
          predicate((error) =>
              error is Exception &&
              error.toString().contains('detections must contain objects')),
        ),
      );
      await backend.disconnect();
    });

    test('times out when the response body stalls after headers', () async {
      final backend = BackendService(
        baseUrl: 'http://test.local',
        requestTimeout: const Duration(milliseconds: 20),
        client: _StalledBodyClient(),
      );

      await expectLater(
        backend.processFrame(Uint8List.fromList([1, 2, 3])),
        throwsA(
          predicate((error) =>
              error is Exception &&
              error.toString().contains('TimeoutException')),
        ),
      );
      await backend.disconnect();
    });
  });
}

class _StalledBodyClient extends http.BaseClient {
  final StreamController<List<int>> _body = StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(_body.stream, 200);
  }

  @override
  void close() {
    _body.close();
  }
}
