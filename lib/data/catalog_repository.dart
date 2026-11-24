/// Catalog source client for the Browse tabs: e-books and novels from
/// Open Library + the Internet Archive, comics from the Internet
/// Archive, manga from MangaDex — no new dependency, only
/// `package:http`, already in the app. Mirrors [NewsRepository]: a
/// 5-minute cache per list, 20s timeout for JSON with 3 attempts, 90s
/// for full text with 2 attempts per IA id, never throws (empty list /
/// null on failure). Gutendex was the original e-books source but it
/// timed out on every attempt on 2026-11-24 and Gutenberg was down for
/// maintenance; Open Library is the verified-live source.
///
/// READABLE-ONLY (2026-11-24): Open Library's `has_fulltext` does NOT
/// mean the text can be downloaded — many IA texts are
/// lending-restricted and answer 401/403 anonymously (5 of the first 8
/// education books). The repo drops restricted IA ids with ONE bulk IA
/// advancedsearch call (`access-restricted-item`) before a book list
/// reaches the screen, so every listed book/novel/comic is actually
/// readable. MangaDex chapters are filtered the same way (only
/// chapters with real pages, no external links).
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
  static const _iaSearchBase = 'https://archive.org/advancedsearch.php';
  static const _mangaBase = 'https://api.mangadex.org';

  final http.Client _client;
  List<CatalogItem>? _ebooksCache;
  DateTime? _ebooksCacheAt;
  String? _ebooksQuery;
  List<CatalogItem>? _novelsCache;
  DateTime? _novelsCacheAt;
  String? _novelsQuery;
  List<CatalogItem>? _comicsCache;
  DateTime? _comicsCacheAt;
  String? _comicsQuery;
  List<CatalogItem>? _mangaCache;
  DateTime? _mangaCacheAt;
  String? _mangaQuery;

  /// One JSON GET with retries (slow/flaky connections stall single
  /// attempts). Returns the decoded object, or null after every
  /// attempt fails (non-200, timeout, bad JSON). Never throws.
  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      try {
        final res = await _client.get(uri).timeout(_jsonTimeout);
        if (res.statusCode != 200) continue;
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Transient stall / DNS failure: retry, then give up.
      }
    }
    return null;
  }

  /// Drops IA ids the user cannot actually read. One bulk IA
  /// advancedsearch call maps ids to their `access-restricted-item`
  /// flag (verified live 2026-11-24: the flag matches the download
  /// result exactly — true means 401/403, absent means 200). An item
  /// keeps only its unrestricted ids and is dropped when none are
  /// left. When the bulk check itself fails, the list is returned
  /// unfiltered (fail open — the per-id download fallback still
  /// applies) rather than dropping everything.
  Future<List<CatalogItem>> _filterReadable(
    List<CatalogItem> items,
  ) async {
    final allIds = items.expand((i) => i.iaIds).toSet().toList();
    if (allIds.isEmpty) return items;
    final restricted = await _fetchRestrictedIds(allIds);
    if (restricted == null) return items;
    final out = <CatalogItem>[];
    for (final item in items) {
      final kept =
          item.iaIds.where((id) => !restricted.contains(id)).toList();
      if (kept.isEmpty) continue;
      out.add(kept.length == item.iaIds.length
          ? item
          : item.copyWith(iaIds: kept));
    }
    return out;
  }

  /// Set of IA ids that are lending-restricted. Ids missing from the
  /// search response count as restricted (a lending-only item can be
  /// absent from the search index — e.g. `isbn_9780593091876`).
  /// Returns null when the check itself fails.
  Future<Set<String>?> _fetchRestrictedIds(List<String> iaIds) async {
    final capped = iaIds.take(100).toList();
    final q = 'identifier:(${capped.join(' OR ')})';
    final uri = Uri.parse(
      '$_iaSearchBase?q=${Uri.encodeQueryComponent(q)}'
      '&fl[]=identifier&fl[]=access-restricted-item'
      '&rows=${capped.length}&page=1&output=json',
    );
    final data = await _getJson(uri);
    if (data == null) return null;
    final docs =
        (data['response'] as Map<String, dynamic>?)?['docs'] as List? ??
            <dynamic>[];
    final seen = <String>{};
    final restricted = <String>{};
    for (final doc in docs.whereType<Map<String, dynamic>>()) {
      final id = doc['identifier'] as String?;
      if (id == null) continue;
      seen.add(id);
      if (doc['access-restricted-item'] == true) restricted.add(id);
    }
    for (final id in capped) {
      if (!seen.contains(id)) restricted.add(id);
    }
    return restricted;
  }

  /// Shared Open Library fetch: decode, parse into items of [type],
  /// then drop the unreadable ones. Returns null on failure.
  Future<List<CatalogItem>?> _fetchOpenLibrary(
    Uri uri,
    CatalogType type,
  ) async {
    final data = await _getJson(uri);
    if (data == null) return null;
    final docs = data['docs'] as List? ?? <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .map((d) => CatalogItem.fromOpenLibrary(d, type: type))
        .whereType<CatalogItem>()
        .toList();
    return _filterReadable(items);
  }

  /// E-books list, most relevant first. [search] is free text; the
  /// default list is education books (`q=education`). Only books with
  /// a usable AND readable full text are returned (the source marks
  /// the rest, and the restriction filter drops the lending-only
  /// ones). The cache is keyed by query; a new query refetches.
  /// Returns null on failure (non-200, timeout, bad JSON) — an empty
  /// list means the search genuinely found nothing. Never throws.
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
    final uri = Uri.parse(
      '$_searchBase?q=${Uri.encodeQueryComponent(query)}'
      '&limit=$_pageSize&fields=$_fields',
    );
    final items = await _fetchOpenLibrary(uri, CatalogType.ebook);
    if (items == null) return null;
    _ebooksCache = items;
    _ebooksCacheAt = DateTime.now();
    _ebooksQuery = query;
    return items;
  }

  /// Novels list from Open Library. Same readable-only shape as
  /// [fetchEbooks]; the default list is fiction (`subject=fiction`),
  /// a free-text [search] switches to a title/author query.
  Future<List<CatalogItem>?> fetchNovels({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (!forceRefresh &&
        _novelsCache != null &&
        _novelsCacheAt != null &&
        _novelsQuery == query &&
        DateTime.now().difference(_novelsCacheAt!) < _cacheTtl) {
      return _novelsCache!;
    }
    final uri = query.isEmpty
        ? Uri.parse(
            '$_searchBase?subject=fiction'
            '&limit=$_pageSize&fields=$_fields',
          )
        : Uri.parse(
            '$_searchBase?q=${Uri.encodeQueryComponent(query)}'
            '&limit=$_pageSize&fields=$_fields',
          );
    final items = await _fetchOpenLibrary(uri, CatalogType.novel);
    if (items == null) return null;
    _novelsCache = items;
    _novelsCacheAt = DateTime.now();
    _novelsQuery = query;
    return items;
  }

  /// Comics list from the Internet Archive (`collection:comics`,
  /// only issues with a Text PDF). The restriction flag rides in the
  /// search response itself, so lending-only issues are dropped
  /// without an extra call. [search] matches issue titles
  /// (`title:(word1 AND word2)`, verified live). Returns null on
  /// failure. Never throws.
  Future<List<CatalogItem>?> fetchComics({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (!forceRefresh &&
        _comicsCache != null &&
        _comicsCacheAt != null &&
        _comicsQuery == query &&
        DateTime.now().difference(_comicsCacheAt!) < _cacheTtl) {
      return _comicsCache!;
    }
    final q = StringBuffer('collection:comics AND format:"Text PDF"');
    if (query.isNotEmpty) {
      final words = query
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      q.write(' AND title:(${words.join(' AND ')})');
    }
    final uri = Uri.parse(
      '$_iaSearchBase?q=${Uri.encodeQueryComponent(q.toString())}'
      '&fl[]=identifier&fl[]=title&fl[]=description'
      '&fl[]=access-restricted-item'
      '&rows=$_pageSize&page=1&output=json',
    );
    final data = await _getJson(uri);
    if (data == null) return null;
    final docs =
        (data['response'] as Map<String, dynamic>?)?['docs'] as List? ??
            <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .where((d) => d['access-restricted-item'] != true)
        .map(CatalogItem.fromInternetArchive)
        .whereType<CatalogItem>()
        .toList();
    _comicsCache = items;
    _comicsCacheAt = DateTime.now();
    _comicsQuery = query;
    return items;
  }

  /// Direct PDF URL for one comic issue. Resolves the filename from
  /// the item's IA metadata (prefer the issue's own `{id}.pdf`, else
  /// the largest PDF — the main scan). Returns null when no PDF is
  /// listed or the metadata fetch fails. Never throws.
  Future<String?> fetchComicPdfUrl(CatalogItem item) async {
    if (item.iaIds.isEmpty) return null;
    final iaId = item.iaIds.first;
    final data =
        await _getJson(Uri.parse('https://archive.org/metadata/$iaId'));
    if (data == null) return null;
    final files = (data['files'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];
    final pdfs = files
        .where((f) => (f['name'] as String? ?? '').endsWith('.pdf'))
        .toList();
    if (pdfs.isEmpty) return null;
    Map<String, dynamic>? pick;
    for (final f in pdfs) {
      if (f['name'] == '$iaId.pdf') {
        pick = f;
        break;
      }
    }
    pick ??= pdfs.reduce(
      (a, b) =>
          ((a['size'] as num?) ?? 0) >= ((b['size'] as num?) ?? 0) ? a : b,
    );
    final name = pick['name'] as String;
    return 'https://archive.org/download/$iaId/${Uri.encodeComponent(name)}';
  }

  /// Manga list from MangaDex, most followed first. [search] matches
  /// titles. Covers ride along (`cover_art`); authors/artists too.
  /// Returns null on failure. Never throws.
  Future<List<CatalogItem>?> fetchManga({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (!forceRefresh &&
        _mangaCache != null &&
        _mangaCacheAt != null &&
        _mangaQuery == query &&
        DateTime.now().difference(_mangaCacheAt!) < _cacheTtl) {
      return _mangaCache!;
    }
    final titleParam = query.isEmpty
        ? ''
        : '&title=${Uri.encodeQueryComponent(query)}';
    final uri = Uri.parse(
      '$_mangaBase/manga?limit=$_pageSize'
      '&includes[]=cover_art&includes[]=author&includes[]=artist'
      '&contentRating[]=safe&contentRating[]=suggestive'
      '&order[followedCount]=desc$titleParam',
    );
    final data = await _getJson(uri);
    if (data == null) return null;
    final docs = data['data'] as List? ?? <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .map(CatalogItem.fromMangaDex)
        .whereType<CatalogItem>()
        .toList();
    _mangaCache = items;
    _mangaCacheAt = DateTime.now();
    _mangaQuery = query;
    return items;
  }

  /// English chapters for one manga, oldest first. Only chapters
  /// with real pages are returned (licensed titles are just external
  /// links — filtered by [MangaChapter.fromMangaDex]). Returns null
  /// on failure. Never throws.
  Future<List<MangaChapter>?> fetchMangaChapters(String mangaId) async {
    final uri = Uri.parse(
      '$_mangaBase/manga/$mangaId/feed?limit=100'
      '&translatedLanguage[]=en&order[chapter]=asc'
      '&includes[]=scanlation_group',
    );
    final data = await _getJson(uri);
    if (data == null) return null;
    final docs = data['data'] as List? ?? <dynamic>[];
    final chapters = docs
        .whereType<Map<String, dynamic>>()
        .map(MangaChapter.fromMangaDex)
        .whereType<MangaChapter>()
        .toList();
    // The API order is numeric already; this is a safety net for
    // string-numbered chapters ("10" after "2").
    chapters.sort((a, b) {
      final an = double.tryParse(a.number) ?? double.infinity;
      final bn = double.tryParse(b.number) ?? double.infinity;
      return an.compareTo(bn);
    });
    return chapters;
  }

  /// Page image URLs for one manga chapter, from MangaDex's at-home
  /// server. Returns null when the chapter has no pages on the
  /// server (stale chapter) or the fetch fails. Never throws.
  Future<MangaPages?> fetchMangaPages(String chapterId) async {
    final data =
        await _getJson(Uri.parse('$_mangaBase/at-home/server/$chapterId'));
    if (data == null) return null;
    final baseUrl = data['baseUrl'] as String?;
    final chapter = data['chapter'] as Map<String, dynamic>?;
    final hash = chapter?['hash'] as String?;
    final files = (chapter?['data'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    if (baseUrl == null || hash == null || files.isEmpty) return null;
    return MangaPages(baseUrl: baseUrl, hash: hash, files: files);
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

  /// Synopsis for one Open Library book/novel. The search document
  /// carries no description, so this fetches the work record
  /// (`/works/{id}.json`) and reads `description` (a string, or a
  /// `{value: ...}` object) — falling back to `first_sentence` when
  /// the work has no description. Returns null when the work has
  /// neither or the fetch fails. Never throws.
  Future<String?> fetchWorkSynopsis(CatalogItem item) async {
    if (item.type != CatalogType.ebook &&
        item.type != CatalogType.novel) {
      return null;
    }
    final workId =
        item.id.startsWith('ol:') ? item.id.substring(3) : '';
    if (workId.isEmpty) return null;
    final data = await _getJson(
      Uri.parse('https://openlibrary.org/works/$workId.json'),
    );
    if (data == null) return null;
    final description = _textField(data['description']) ??
        _textField(data['first_sentence']);
    final text = description?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// An Open Library text field is either a plain string or a
  /// `{value: "..."}` object.
  static String? _textField(dynamic value) {
    if (value is String) return value;
    if (value is Map<String, dynamic>) return value['value'] as String?;
    return null;
  }
}
