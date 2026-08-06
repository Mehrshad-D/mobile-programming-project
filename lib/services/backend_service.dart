import 'dart:async';
import 'dart:convert';
import 'dart:io';

class BackendException implements Exception {
  const BackendException(this.message, {this.code = 'request_failed'});

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract class BackendApi {
  String? token;

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> profile();
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String bio,
  });
  Future<List<Map<String, dynamic>>> lists();
  Future<Map<String, dynamic>> createList(String name);
  Future<void> deleteList(int id);
  Future<void> addListItem(int listId, String mediaId);
  Future<void> removeListItem(int listId, String mediaId);
  Future<Map<String, dynamic>> activity();
  Future<void> setWatchStatus(String mediaId, String status);
  Future<void> setEpisodeWatched(int episodeId, bool watched);
  Future<void> rate(String mediaId, int value);
  Future<void> setFavorite(String mediaId, bool favorite);
  Future<void> addReview(String mediaId, String text, bool spoiler);
}

class BackendService implements BackendApi {
  static const _configuredUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  BackendService() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  final HttpClient _client = HttpClient();

  @override
  String? token;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      },
    );
    token = result['access_token'] as String;
    return profile();
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    token = result['access_token'] as String;
    return profile();
  }

  @override
  Future<Map<String, dynamic>> profile() => _request('GET', '/users/me');

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) => _request(
    'PATCH',
    '/users/me',
    body: {'name': name, 'username': username, 'bio': bio},
  );

  @override
  Future<List<Map<String, dynamic>>> lists() async {
    final result = await _request('GET', '/me/lists');
    return (result['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> createList(String name) =>
      _request('POST', '/me/lists', body: {'name': name});

  @override
  Future<void> deleteList(int id) => _empty('DELETE', '/me/lists/$id');

  @override
  Future<void> addListItem(int listId, String mediaId) =>
      _empty('PUT', '/me/lists/$listId/items', body: {'media_id': mediaId});

  @override
  Future<void> removeListItem(int listId, String mediaId) =>
      _empty('DELETE', '/me/lists/$listId/items/$mediaId');

  @override
  Future<Map<String, dynamic>> activity() => _request('GET', '/me/activity');

  @override
  Future<void> setWatchStatus(String mediaId, String status) =>
      _empty('PUT', '/me/watch-status/$mediaId', body: {'status': status});

  @override
  Future<void> setEpisodeWatched(int episodeId, bool watched) => _empty(
    'PUT',
    '/me/episodes/$episodeId/watched',
    body: {'watched': watched},
  );

  @override
  Future<void> rate(String mediaId, int value) =>
      _empty('PUT', '/me/ratings/$mediaId', body: {'value': value});

  @override
  Future<void> setFavorite(String mediaId, bool favorite) =>
      _empty(favorite ? 'PUT' : 'DELETE', '/me/favorites/$mediaId');

  @override
  Future<void> addReview(String mediaId, String text, bool spoiler) => _empty(
    'POST',
    '/media/$mediaId/reviews',
    body: {'text': text, 'spoiler': spoiler},
  );

  Future<void> _empty(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _request(method, path, body: body, allowEmpty: true);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool allowEmpty = false,
  }) async {
    final base = Uri.parse(_configuredUrl);
    final uri = base.replace(path: '${base.path}$path');
    try {
      final request = await _client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'] as Map<String, dynamic>?;
        throw BackendException(
          _localizedError(
            error?['code']?.toString(),
            error?['message']?.toString(),
          ),
          code: error?['code']?.toString() ?? 'request_failed',
        );
      }
      if (!allowEmpty && responseBody.isEmpty) {
        throw const BackendException('پاسخ سرور خالی است.');
      }
      return decoded;
    } on BackendException {
      rethrow;
    } on SocketException {
      throw const BackendException('ارتباط با سرور پروژه برقرار نیست.');
    } on TimeoutException {
      throw const BackendException('زمان دریافت پاسخ از سرور پایان یافت.');
    } on FormatException {
      throw const BackendException('پاسخ سرور معتبر نیست.');
    }
  }

  static String _localizedError(String? code, String? fallback) =>
      switch (code) {
        'invalid_credentials' => 'ایمیل یا رمز عبور نادرست است.',
        'account_exists' => 'این ایمیل یا نام کاربری قبلاً ثبت شده است.',
        'username_exists' => 'این نام کاربری قبلاً استفاده شده است.',
        'invalid_token' => 'نشست شما منقضی شده است؛ دوباره وارد شوید.',
        'validation_error' => 'اطلاعات واردشده معتبر نیست.',
        _ => fallback ?? 'درخواست به سرور ناموفق بود.',
      };
}
