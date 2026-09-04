import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown by [ApiClient] on any non-2xx response, so every screen can
/// catch one exception type instead of inspecting status codes itself.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Single place that knows the API's base URL and does request/response
/// plumbing. Services call through this rather than using `http` directly.
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({required this.baseUrl, http.Client? client})
      : _http = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _http.get(_uri(path, query));
    return _decode(response);
  }

  /// Like [get], but `pathWithQuery` already contains its full query
  /// string. Needed when a query key repeats (e.g. `?retailer_ids=a&retailer_ids=b`),
  /// which the `Map<String, dynamic>` shape of [get]'s `query` param can't express.
  Future<dynamic> getRaw(String pathWithQuery) async {
    final response = await _http.get(Uri.parse('$baseUrl$pathWithQuery'));
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _http.delete(_uri(path));
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.body.isNotEmpty ? response.body : 'Request failed',
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}