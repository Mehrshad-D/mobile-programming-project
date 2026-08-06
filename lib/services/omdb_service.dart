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

/// Direct external catalogue adapter for IMDb identifiers via OMDb.
class OmdbService {
  static const _apiKey = '8965a68a';
  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<MediaItem>> search(String query) async {
    if (!isConfigured) return const [];
    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': _apiKey,
      's': query,
    });
    final json = await _get(uri);
    if (json['Response'] == 'False') {
      if (json['Error'] == 'Movie not found!') return const [];
      throw CatalogException(
        json['Error']?.toString() ?? 'خطا در دریافت اطلاعات',
      );
    }
    final hits = (json['Search'] as List<dynamic>? ?? const []).take(10);
    final details = await Future.wait(
      hits.map((e) => findById(e['imdbID'] as String)),
    );
    return details.whereType<MediaItem>().toList();
  }

  Future<MediaItem?> findById(String id) async {
    if (!isConfigured) return null;
    final json = await _get(
      Uri.https('www.omdbapi.com', '/', {
        'apikey': _apiKey,
        'i': id,
        'plot': 'full',
      }),
    );
    if (json['Response'] == 'False') return null;
    final type = json['Type'] == 'series' ? MediaType.series : MediaType.movie;
    int number(String? raw) =>
        int.tryParse((raw ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    double decimal(String? raw) => double.tryParse(raw ?? '') ?? 0;
    final yearParts = (json['Year']?.toString() ?? '').split(
      RegExp(r'[^0-9]+'),
    );
    return MediaItem(
      id: json['imdbID'] as String,
      title: json['Title']?.toString() ?? 'بدون عنوان',
      originalTitle: json['Title']?.toString() ?? '',
      type: type,
      posterUrl: json['Poster'] == 'N/A'
          ? ''
          : json['Poster']?.toString() ?? '',
      backdropUrl: '',
      overview: json['Plot'] == 'N/A'
          ? 'خلاصه‌ای ثبت نشده است.'
          : json['Plot']?.toString() ?? '',
      year: yearParts.isEmpty ? 0 : int.tryParse(yearParts.first) ?? 0,
      endYear: yearParts.length > 1 ? int.tryParse(yearParts.last) : null,
      genres: (json['Genre']?.toString() ?? '')
          .split(', ')
          .where((e) => e.isNotEmpty)
          .toList(),
      rating: decimal(json['imdbRating']?.toString()),
      runtime: number(json['Runtime']?.toString()),
      country: json['Country']?.toString() ?? '-',
      director: json['Director']?.toString() ?? '-',
      cast: (json['Actors']?.toString() ?? '')
          .split(', ')
          .where((e) => e.isNotEmpty)
          .toList(),
      status: type == MediaType.series ? 'اطلاعات IMDb' : 'منتشر شده',
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await (await client.getUrl(
        uri,
      )).close().timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const CatalogException('سرویس اطلاعات در دسترس نیست.');
      }
      return jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
    } on SocketException {
      throw const CatalogException('اتصال اینترنت برقرار نیست.');
    } on TimeoutException {
      throw const CatalogException('زمان دریافت اطلاعات به پایان رسید.');
    } finally {
      client.close(force: true);
    }
  }
}
