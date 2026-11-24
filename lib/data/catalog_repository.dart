/// Catalog source client for the Browse tabs: e-books (and later novels)
/// from Open Library + the Internet Archive, no new dependency — only
/// `package:http`, already in the app. Mirrors [NewsRepository]: a
/// 5-minute cache per list, 20s timeout for JSON with 3 attempts, 90s
/// for full text with 2 attempts per IA id, never throws (empty list /
/// null on failure). Gutendex was the original e-books source but it
/// timed out on every attempt on 2026-11-24 and Gutenberg was down for
/// maintenance; Open Library is the verified-live source. When Gutendex
/// recovers, add it behind the same [CatalogItem] shape — the screens
/// never see the source.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog.dart';

class CatalogRepository {
  CatalogRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _searchBase = 'https://openlibrary.org/search.json';
  static const _fields = 'key,title,author_name,cover_i,subject,has_fulltext,ia';
  static const _pageSize = 32;
  static const _cacheTtl = Duration(minutes: 5);
  static const _jsonTimeout = Duration(seconds: 20);
  static const _textTimeout = Duration(seconds: 90);
  static const _maxAttempts = 3;

  final http.Client _client;
  List<CatalogItem>? _ebooksCache;
  DateTime? _ebooksCacheAt;
  String? _ebooksQuery;

  /// E-books list, most relevant first. [search] is free text; the
  /// default list is education books (`q=education`). Only books with
  /// a usable full text are returned (the source marks the rest). The
  /// cache is keyed by query; a new query refetches. Returns null on
  /// failure (non-200, timeout, bad JSON) — an empty list means the
  /// search genuinely found nothing. Never throws.
  Future<List<CatalogItem>?> fetchEbooks({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? 'education'
        : search.trim();
    if (!forceRefresh &&
        _ebooksCache != null &&
        _ebooksCacheAt != null &&
        _ebooksQuery == query &&
        DateTime.now().difference(_ebooksCacheAt!) < _cacheTtl) {
      return _ebooksCache!;
    }
    final items = await _fetchSearch(query);
    if (items == null) return null;
    _ebooksCache = items;
    _ebooksCacheAt = DateTime.now();
    _ebooksQuery = query;
    return items;
  }

  Future<List<CatalogItem>?> _fetchSearch(String query) async {
    // One slow or flaky connection can stall a single attempt (virgil's
    // network times out on hosts that answer fine elsewhere — both the
    // search and the chapter download showed "check your connection"
    // on his connection while the same URLs answered in ~2s/6s here),
    // so retry a few times before giving up. The tab only shows its
    // error state after every attempt fails.
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      try {
        final uri = Uri.parse(
          '$_searchBase?q=${Uri.encodeQueryComponent(query)}'
          '&limit=$_pageSize&fields=$_fields',
        );
        final res = await _client.get(uri).timeout(_jsonTimeout);
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final docs = data['docs'] as List? ?? <dynamic>[];
        return docs
            .whereType<Map<String, dynamic>>()
            .map(CatalogItem.fromOpenLibrary)
            .whereType<CatalogItem>()
            .toList();
      } catch (_) {
        // Transient stall / DNS failure: retry, then give up.
      }
    }
    return null;
  }

  /// Full plain text for a book. Tries each IA id in order and takes
  /// the first non-empty body (IA answers 302, its normal redirect;
  /// `http` follows it). Retries once per id on timeout. Returns null
  /// when no id yields text. Never throws.
  Future<String?> fetchFullText(CatalogItem item) async {
    for (final iaId in item.iaIds) {
      final url = CatalogItem.textUrlForIa(iaId);
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res =
              await _client.get(Uri.parse(url)).timeout(_textTimeout);
          if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
            return res.body;
          }
          break; // Non-200 or empty: try the next IA id, not a retry.
        } catch (_) {
          if (attempt == 1) break; // Retried once already: next IA id.
        }
      }
    }
    return null;
  }
}
