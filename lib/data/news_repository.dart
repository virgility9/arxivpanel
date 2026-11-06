/// Live education/science headlines for the Feed tab.
///
/// Fetches RSS feeds through the free rss2json proxy (plain JSON over
/// HTTPS, so it works on web — a direct RSS fetch would hit CORS — and on
/// Android, with no new dependency: only `package:http`, already in the
/// app). Each source is fetched independently, so one dead feed never
/// takes the whole list down. Results are cached for 5 minutes.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class NewsRepository {
  NewsRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _proxy = 'https://api.rss2json.com/v1/api.json?rss_url=';

  /// Verified live 2026-11-06 (rss2json returns `status: ok` with fresh
  /// items for both). Edutopia's feed 422s through the proxy, so it is
  /// not listed — do not add it back without re-verifying.
  static const _sources = <({String feedUrl, String name})>[
    (
      feedUrl: 'https://www.sciencedaily.com/rss/top/science.xml',
      name: 'ScienceDaily',
    ),
    (feedUrl: 'https://phys.org/rss-feed/', name: 'Phys.org'),
  ];

  static const _cacheTtl = Duration(minutes: 5);
  static const _maxItems = 30;

  final http.Client _client;
  List<NewsItem>? _cache;
  DateTime? _cacheAt;

  /// Live headlines, newest first. Returns the cached list when it is
  /// fresh unless [forceRefresh] is true. Never throws — a failed source
  /// contributes nothing, and a total failure returns an empty list.
  Future<List<NewsItem>> fetchLiveNews({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }
    final results = await Future.wait(_sources.map(_fetchSource));
    final items = results.expand((list) => list).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final trimmed = items.take(_maxItems).toList();
    _cache = trimmed;
    _cacheAt = DateTime.now();
    return trimmed;
  }

  Future<List<NewsItem>> _fetchSource(
    ({String feedUrl, String name}) source,
  ) async {
    try {
      final uri = Uri.parse(
        '$_proxy${Uri.encodeComponent(source.feedUrl)}',
      );
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return <NewsItem>[];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'ok') return <NewsItem>[];
      final items = data['items'] as List? ?? <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => NewsItem.fromLiveJson(item, source.name))
          .toList();
    } catch (_) {
      return <NewsItem>[];
    }
  }
}
