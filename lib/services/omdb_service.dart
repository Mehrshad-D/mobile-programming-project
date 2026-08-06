import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/media.dart';

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Advanced-model catalogue adapter. The Flutter client talks only to the
/// project backend; the OMDb key and external API traffic remain server-side.
class OmdbService {
  static const _configuredUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  bool get isConfigured => _configuredUrl.isNotEmpty;

  Future<List<MediaItem>> search(String query) async {
    if (!isConfigured) return const [];
    final json = await _get('/media/search', {'q': query});
    return (json['items'] as List<dynamic>? ?? const [])
        .map((item) => _media(item as Map<String, dynamic>))
        .toList();
  }

  Future<MediaItem?> findById(String id, {bool includeEpisodes = false}) async {
    if (!isConfigured) return null;
    final json = await _get('/media/$id', {
      'include_episodes': '$includeEpisodes',
    });
    return _media(json);
  }

  MediaItem _media(Map<String, dynamic> json) => MediaItem(
    id: json['id'] as String,
    title: json['title']?.toString() ?? 'بدون عنوان',
    originalTitle: json['originalTitle']?.toString() ?? '',
    type: json['type'] == 'series' ? MediaType.series : MediaType.movie,
    posterUrl: json['posterUrl']?.toString() ?? '',
    backdropUrl: json['backdropUrl']?.toString() ?? '',
    overview: json['overview']?.toString() ?? '',
    year: (json['year'] as num?)?.toInt() ?? 0,
    endYear: (json['endYear'] as num?)?.toInt(),
    genres: (json['genres'] as List<dynamic>? ?? const []).cast<String>(),
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    runtime: (json['runtime'] as num?)?.toInt() ?? 0,
    country: json['country']?.toString() ?? '-',
    director: json['director']?.toString() ?? '-',
    cast: (json['cast'] as List<dynamic>? ?? const []).cast<String>(),
    status: json['status']?.toString() ?? 'IMDb',
    declaredSeasonCount: (json['declaredSeasonCount'] as num?)?.toInt() ?? 0,
    episodes: (json['episodes'] as List<dynamic>? ?? const [])
        .map((episode) => _episode(episode as Map<String, dynamic>))
        .toList(),
  );

  Episode _episode(Map<String, dynamic> json) => Episode(
    databaseId: (json['databaseId'] as num?)?.toInt(),
    season: (json['season'] as num).toInt(),
    number: (json['number'] as num).toInt(),
    title: json['title']?.toString() ?? 'بدون عنوان',
    runtime: (json['runtime'] as num?)?.toInt() ?? 0,
    overview: json['overview']?.toString() ?? '',
  );

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final base = Uri.parse(_configuredUrl);
    final uri = base.replace(path: '${base.path}$path', queryParameters: query);
    try {
      final response = await (await _client.getUrl(
        uri,
      )).close().timeout(const Duration(seconds: 30));
      final body = await utf8.decoder.bind(response).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = json['error'] as Map<String, dynamic>?;
        throw CatalogException(
          error?['message']?.toString() ?? 'خطا در دریافت اطلاعات',
        );
      }
      return json;
    } on SocketException {
      throw const CatalogException('ارتباط با سرور پروژه برقرار نیست.');
    } on TimeoutException {
      throw const CatalogException('زمان دریافت اطلاعات از سرور پایان یافت.');
    } on FormatException {
      throw const CatalogException('پاسخ سرور معتبر نیست.');
    }
  }
}
