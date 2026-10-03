import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/navigation_model.dart';
import '../models/sign_reading.dart';

class BackendService {
  BackendService({
    required String baseUrl,
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 30),
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _client = client,
        _requestTimeout = requestTimeout;

  final String baseUrl;
  bool _connected = false;
  http.Client? _client;
  http.Client get _httpClient => _client ??= http.Client();
  static const Duration _healthTimeout = Duration(seconds: 10);
  final Duration _requestTimeout;

  Future<bool> connect() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_healthTimeout);
      _connected = response.statusCode == 200;
      if (!_connected) {
        throw Exception(
            'Backend health check failed with status ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      _connected = false;
      throw Exception(
          'Network error: ${e.message}. Ensure backend is running and accessible.');
    } catch (e) {
      _connected = false;
      throw Exception('Connection error: $e');
    }
    return _connected;
  }

  Future<bool> disconnect() async {
    _connected = false;
    _client?.close();
    _client = null;
    return true;
  }

  Future<NavigationModel> processFrame(Uint8List frameData) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze-frame'),
      )..files.add(http.MultipartFile.fromBytes(
          'image',
          frameData,
          filename: 'frame.jpg',
        ));

      final streamedResponse =
          await _httpClient.send(request).timeout(_requestTimeout);
      final body = await streamedResponse.stream
          .bytesToString()
          .timeout(_requestTimeout);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Backend error: ${streamedResponse.statusCode} - $body');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;

      // Validate response structure
      if (!decoded.containsKey('action')) {
        throw Exception('Invalid response: missing action field');
      }
      if (!decoded.containsKey('reason')) {
        throw Exception('Invalid response: missing reason field');
      }
      if (!decoded.containsKey('detections')) {
        throw Exception('Invalid response: missing detections field');
      }
      const validActions = {
        'CONTINUE',
        'STOP',
        'MOVE LEFT',
        'MOVE RIGHT',
        'CAUTION / SLOW DOWN',
      };
      if (decoded['action'] is! String ||
          !validActions.contains(decoded['action'])) {
        throw const FormatException('Invalid response: unsupported action');
      }
      if (decoded['reason'] is! String ||
          (decoded['reason'] as String).trim().isEmpty) {
        throw const FormatException('Invalid response: invalid reason');
      }
      if (decoded['priority'] is! String ||
          !const {'LOW', 'MEDIUM', 'HIGH'}.contains(decoded['priority'])) {
        throw const FormatException('Invalid response: invalid priority');
      }
      if (decoded['detections'] is! List) {
        throw const FormatException(
            'Invalid response: detections must be a list');
      }
      final detections = decoded['detections'] as List;
      if (detections.any((detection) => detection is! Map<String, dynamic>)) {
        throw const FormatException(
            'Invalid response: detections must contain objects');
      }

      _connected = true;
      return NavigationModel.fromJson(decoded);
    } on http.ClientException catch (e) {
      _connected = false;
      throw Exception('Network error during frame analysis: ${e.message}');
    } on FormatException catch (e) {
      _connected = false;
      throw Exception('Invalid JSON response from backend: $e');
    } catch (e) {
      _connected = false;
      throw Exception('Frame analysis error: $e');
    }
  }

  Future<SignReading> readSign(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/read-sign'),
      )..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'sign.jpg',
        ));

      final response = await _httpClient.send(request).timeout(_requestTimeout);
      final body =
          await response.stream.bytesToString().timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
            'Sign reading failed with status ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return SignReading.fromJson(decoded);
    } on http.ClientException catch (error) {
      throw Exception('Sign reading network error: ${error.message}');
    } on FormatException catch (error) {
      throw Exception('Invalid sign-reading response: $error');
    } catch (error) {
      throw Exception('Sign reading unavailable: $error');
    }
  }

  bool isConnected() => _connected;

  String getStatus() =>
      _connected ? 'Backend connected' : 'Backend not connected';
}
