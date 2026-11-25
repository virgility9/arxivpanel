/// Catalog source client for the Browse tabs: e-books and novels from
/// Open Library + the Internet Archive, comics from the Internet
/// Archive, manga from MangaDex — no new dependency, only
/// `package:http`, already in the app. Mirrors [NewsRepository]: a
/// 5-minute cache per list (page 1), 20-item pages with Load more,
/// 20s timeout for JSON with 3 attempts, 90s for full text with 2
/// attempts per IA id, never throws (empty page / null on failure).
/// Searches are debounced in the tabs and cancellable here: a new
/// search for a list closes the previous search's client, aborting
/// it in flight, and a repeat query is answered from the cache.
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
  static const _pageSize = 20;
  static const _cacheTtl = Duration(minutes: 5);
  static const _jsonTimeout = Duration(seconds: 20);
  static const _textTimeout = Duration(seconds: 90);
  static const _maxAttempts = 3;
  static const _iaSearchBase = 'https://archive.org/advancedsearch.php';
  static const _mangaBase = 'https://api.mangadex.org';

  final http.Client _client;
  CatalogPage? _ebooksCache;
  DateTime? _ebooksCacheAt;
  String? _ebooksQuery;
  CatalogPage? _novelsCache;
  DateTime? _novelsCacheAt;
  String? _novelsQuery;
  CatalogPage? _comicsCache;
  DateTime? _comicsCacheAt;
  String? _comicsQuery;
  CatalogPage? _mangaCache;
  DateTime? _mangaCacheAt;
  String? _mangaQuery;

  /// One live search client per list. A new search for a list closes
  /// the previous one first, so an outdated in-flight request is
  /// aborted on the spot instead of finishing late and overwriting
  /// the newer results (its retry loop fails fast on the closed
  /// client). The shared [_client] keeps serving everything else
  /// (texts, chapters, synopses).
  http.Client? _ebooksSearchClient;
  http.Client? _novelsSearchClient;
  http.Client? _comicsSearchClient;
  http.Client? _mangaSearchClient;

  /// Local cache for the heavy per-item downloads, so re-opening a
  /// book / manga / chapter is instant instead of re-downloading:
  /// full book texts (capped — each is ~700KB), manga chapter lists
  /// and chapter page lists (small JSON). Source data is immutable,
  /// so no TTL is needed; the caps keep memory bounded.
  final Map<String, String> _fullTextCache = <String, String>{};
  final Map<String, List<MangaChapter>> _mangaChaptersCache =
      <String, List<MangaChapter>>{};
  final Map<String, MangaPages> _mangaPagesCache = <String, MangaPages>{};
  static const _fullTextCacheCap = 8;
  static const _mangaCacheCap = 20;

  /// Stores [value] under [key], dropping the oldest entry when the
  /// cache is at its cap (insertion-ordered map: the first key is
  /// the oldest).
  void _cachePut<K, V>(Map<K, V> cache, K key, V value, int cap) {
    cache.remove(key);
    if (cache.length >= cap) cache.remove(cache.keys.first);
    cache[key] = value;
  }

  /// One JSON GET with retries (slow/flaky connections stall single
  /// attempts). Returns the decoded object, or null after every
  /// attempt fails (non-200, timeout, bad JSON). Never throws.
  /// [client] defaults to the shared client; list searches pass their
  /// own per-list client so a superseding search can close it.
  Future<Map<String, dynamic>?> _getJson(
    Uri uri, {
    http.Client? client,
  }) async {
    final c = client ?? _client;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      try {
        final res = await c.get(uri).timeout(_jsonTimeout);
        if (res.statusCode != 200) continue;
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Transient stall / DNS failure — or the client was closed
        // because a newer search superseded this one: retry, then
        // give up (a closed client fails every attempt at once).
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
  ///
  /// An item with NO unrestricted ids gets one more chance first:
  /// a free IA copy under the same title (see [_findFreeIaCopies]).
  /// Popular books are often borrow-only on every Open Library copy
  /// while IA hosts a free upload Open Library never links to — those
  /// books used to vanish from the list entirely.
  Future<List<CatalogItem>> _filterReadable(
    List<CatalogItem> items, {
    http.Client? client,
  }) async {
    final allIds = items.expand((i) => i.iaIds).toSet().toList();
    if (allIds.isEmpty) return items;
    final restricted = await _fetchRestrictedIds(allIds, client: client);
    if (restricted == null) return items;
    // Usable ids per item, in list order. Items with none left are
    // rescued below instead of dropped.
    final keptPerItem = <List<String>>[];
    final droppedIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      final kept = items[i]
          .iaIds
          .where((id) => !restricted.contains(id))
          .toList();
      keptPerItem.add(kept);
      if (kept.isEmpty) droppedIndices.add(i);
    }
    final rescuedIds = <int, List<String>>{};
    if (droppedIndices.isNotEmpty) {
      final found = await Future.wait(
        droppedIndices.map(
          (i) => _findFreeIaCopies(items[i], client: client),
        ),
      );
      for (var j = 0; j < droppedIndices.length; j++) {
        if (found[j].isNotEmpty) rescuedIds[droppedIndices[j]] = found[j];
      }
    }
    final out = <CatalogItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final kept = keptPerItem[i];
      if (kept.isNotEmpty) {
        out.add(kept.length == item.iaIds.length
            ? item
            : item.copyWith(iaIds: kept));
      } else if (rescuedIds.containsKey(i)) {
        // The Open Library copies are all borrow-only, but IA hosts
        // a free copy — keep the book, reading from the free copy.
        out.add(item.copyWith(iaIds: rescuedIds[i]!));
      }
    }
    return out;
  }

  /// Free IA copies of a book, by title + author — the rescue path
  /// for books whose Open Library copies are all lending-restricted
  /// (borrow-only). IA hosts free user uploads of many popular books
  /// that Open Library never links to (verified live 2026-11-25 for
  /// "Dog Days": the OL copies are all restricted, while IA search
  /// finds free items like `diary-of-a-wimpy-kid-book-04-dog-days_202504`).
  /// Returns up to 3 free IA ids, or empty when there is no free copy
  /// or the search fails. Never throws.
  Future<List<String>> _findFreeIaCopies(
    CatalogItem item, {
    http.Client? client,
  }) async {
    final words = _titleWords(item.title);
    if (words.isEmpty) return [];
    final titleQuery = 'title:(${words.join(' AND ')})';
    final author = item.authors.isEmpty ? '' : item.authors.first.trim();
    final surname = author.split(RegExp(r'\s+')).lastWhere(
          (w) => w.isNotEmpty,
          orElse: () => '',
        );
    final creatorQuery = surname.isEmpty ? '' : ' AND creator:($surname)';
    final uri = Uri.parse(
      '$_iaSearchBase?q=${Uri.encodeQueryComponent('$titleQuery$creatorQuery AND mediatype:texts')}'
      '&fl[]=identifier&fl[]=access-restricted-item'
      '&rows=10&page=1&output=json',
    );
    final data = await _getJson(uri, client: client);
    if (data == null) return [];
    final docs =
        (data['response'] as Map<String, dynamic>?)?['docs'] as List? ??
            <dynamic>[];
    final free = <String>[];
    for (final doc in docs.whereType<Map<String, dynamic>>()) {
      if (doc['access-restricted-item'] == true) continue;
      final id = doc['identifier'] as String?;
      if (id == null || id.isEmpty || free.contains(id)) continue;
      free.add(id);
      if (free.length >= 3) break;
    }
    return free;
  }

  /// Set of IA ids that are lending-restricted. Ids missing from the
  /// search response count as restricted (a lending-only item can be
  /// absent from the search index — e.g. `isbn_9780593091876`).
  /// Returns null when the check itself fails.
  Future<Set<String>?> _fetchRestrictedIds(
    List<String> iaIds, {
    http.Client? client,
  }) async {
    // The IA query stays bounded (100 ids per call); a page with
    // more ids is checked in chunks instead of silently leaving the
    // rest unchecked (unchecked ids used to slip through as
    // "readable" and then fail to load).
    final restricted = <String>{};
    for (var i = 0; i < iaIds.length; i += 100) {
      final chunk = iaIds.skip(i).take(100).toList();
      final part = await _fetchRestrictedChunk(chunk, client: client);
      if (part == null) return null;
      restricted.addAll(part);
    }
    return restricted;
  }

  /// One bounded chunk of the restricted check (see
  /// [_fetchRestrictedIds]). Returns null when the check fails.
  Future<Set<String>?> _fetchRestrictedChunk(
    List<String> iaIds, {
    http.Client? client,
  }) async {
    final q = 'identifier:(${iaIds.join(' OR ')})';
    final uri = Uri.parse(
      '$_iaSearchBase?q=${Uri.encodeQueryComponent(q)}'
      '&fl[]=identifier&fl[]=access-restricted-item'
      '&rows=${iaIds.length}&page=1&output=json',
    );
    final data = await _getJson(uri, client: client);
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
    for (final id in iaIds) {
      if (!seen.contains(id)) restricted.add(id);
    }
    return restricted;
  }

  /// Shared Open Library fetch: decode, parse into items of [type],
  /// then drop the unreadable ones. Returns the page plus whether the
  /// source has more pages (`numFound` vs this page's end). Returns
  /// null on failure.
  Future<CatalogPage?> _fetchOpenLibrary(
    Uri uri,
    CatalogType type,
    int page, {
    http.Client? client,
  }) async {
    final data = await _getJson(uri, client: client);
    if (data == null) return null;
    final docs = data['docs'] as List? ?? <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .map((d) => CatalogItem.fromOpenLibrary(d, type: type))
        .whereType<CatalogItem>()
        .toList();
    final readable = await _filterReadable(items, client: client);
    final numFound = (data['numFound'] as num?)?.toInt() ?? 0;
    return CatalogPage(
      items: readable,
      hasMore: page * _pageSize < numFound,
    );
  }

  /// E-books list, most relevant first. [search] is free text; the
  /// default list is education books (`q=education`). Only books with
  /// a usable AND readable full text are returned (the source marks
  /// the rest, and the restriction filter drops the lending-only
  /// ones). Results come in pages of [_pageSize]; [page] is 1-based.
  /// The cache is keyed by query and covers page 1 only — later pages
  /// always fetch (a repeat search resets to page 1, so cached page 1
  /// is what backspacing and re-searching hits). A superseding search
  /// closes the previous search's client, aborting it in flight.
  /// Returns null on failure (non-200, timeout, bad JSON) — an empty
  /// page means the search genuinely found nothing. Never throws.
  Future<CatalogPage?> fetchEbooks({
    String? search,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? 'education'
        : search.trim();
    if (page == 1 &&
        !forceRefresh &&
        _ebooksCache != null &&
        _ebooksCacheAt != null &&
        _ebooksQuery == query &&
        DateTime.now().difference(_ebooksCacheAt!) < _cacheTtl) {
      return _ebooksCache!;
    }
    _ebooksSearchClient?.close();
    final client = _ebooksSearchClient = http.Client();
    final uri = Uri.parse(
      '$_searchBase?q=${Uri.encodeQueryComponent(query)}'
      '&limit=$_pageSize&page=$page&fields=$_fields',
    );
    final result = await _fetchOpenLibrary(
      uri,
      CatalogType.ebook,
      page,
      client: client,
    );
    if (result == null) return null;
    if (page == 1) {
      _ebooksCache = result;
      _ebooksCacheAt = DateTime.now();
      _ebooksQuery = query;
    }
    return result;
  }

  /// Novels list from Open Library. Same readable-only shape as
  /// [fetchEbooks]; the default list is fiction (`subject=fiction`),
  /// a free-text [search] switches to a title/author query.
  Future<CatalogPage?> fetchNovels({
    String? search,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (page == 1 &&
        !forceRefresh &&
        _novelsCache != null &&
        _novelsCacheAt != null &&
        _novelsQuery == query &&
        DateTime.now().difference(_novelsCacheAt!) < _cacheTtl) {
      return _novelsCache!;
    }
    _novelsSearchClient?.close();
    final client = _novelsSearchClient = http.Client();
    final uri = query.isEmpty
        ? Uri.parse(
            '$_searchBase?subject=fiction'
            '&limit=$_pageSize&page=$page&fields=$_fields',
          )
        : Uri.parse(
            '$_searchBase?q=${Uri.encodeQueryComponent(query)}'
            '&limit=$_pageSize&page=$page&fields=$_fields',
          );
    final result = await _fetchOpenLibrary(
      uri,
      CatalogType.novel,
      page,
      client: client,
    );
    if (result == null) return null;
    if (page == 1) {
      _novelsCache = result;
      _novelsCacheAt = DateTime.now();
      _novelsQuery = query;
    }
    return result;
  }

  /// Comics list from the Internet Archive (`collection:comics`,
  /// only issues with a Text PDF). The restriction flag rides in the
  /// search response itself, so lending-only issues are dropped
  /// without an extra call. [search] matches issue titles
  /// (`title:(word1 AND word2)`, verified live). Returns null on
  /// failure. Never throws.
  Future<CatalogPage?> fetchComics({
    String? search,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (page == 1 &&
        !forceRefresh &&
        _comicsCache != null &&
        _comicsCacheAt != null &&
        _comicsQuery == query &&
        DateTime.now().difference(_comicsCacheAt!) < _cacheTtl) {
      return _comicsCache!;
    }
    _comicsSearchClient?.close();
    final client = _comicsSearchClient = http.Client();
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
      '&rows=$_pageSize&page=$page&output=json',
    );
    final data = await _getJson(uri, client: client);
    if (data == null) return null;
    final response = data['response'] as Map<String, dynamic>?;
    final docs = response?['docs'] as List? ?? <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .where((d) => d['access-restricted-item'] != true)
        .map(CatalogItem.fromInternetArchive)
        .whereType<CatalogItem>()
        .toList();
    final numFound = (response?['numFound'] as num?)?.toInt() ?? 0;
    final result = CatalogPage(
      items: items,
      hasMore: page * _pageSize < numFound,
    );
    if (page == 1) {
      _comicsCache = result;
      _comicsCacheAt = DateTime.now();
      _comicsQuery = query;
    }
    return result;
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

  /// Direct PDF URL for one book or novel, for the books whose text
  /// won't load at all (no readable `.txt` anywhere — a scanned book
  /// with no OCR text). The detail screen offers it as "Read as PDF"
  /// in the same in-app viewer comics use. Tries each IA id in order;
  /// inside one item it prefers a PDF whose name holds the book's
  /// title words (a series collection holds one PDF per book), then
  /// the item's own `{id}.pdf`, then the largest scan. `_text.pdf`
  /// derivatives (OCR text as a PDF) are only a last resort — the
  /// real scan is the book. Returns null when no PDF is listed or
  /// the metadata fetch fails. Never throws.
  Future<String?> fetchBookPdfUrl(CatalogItem item) async {
    if (item.iaIds.isEmpty) return null;
    final words = _titleWords(item.title);
    // A borrow-only copy still lists its PDF in the metadata, but
    // the download 401s — offering that URL would show the viewer a
    // "Could not load the PDF (HTTP 401)" dead end. Skip restricted
    // ids first (same bulk flag the list filter uses). When the
    // check itself fails, try the PDFs anyway (fail open).
    final restricted = await _fetchRestrictedIds(item.iaIds);
    final ids = restricted == null
        ? item.iaIds
        : item.iaIds.where((id) => !restricted.contains(id)).toList();
    for (final iaId in ids) {
      final data =
          await _getJson(Uri.parse('https://archive.org/metadata/$iaId'));
      if (data == null) continue;
      final files = (data['files'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          <Map<String, dynamic>>[];
      final pdfs = files
          .where((f) => (f['name'] as String? ?? '').endsWith('.pdf'))
          .toList();
      if (pdfs.isEmpty) continue;
      final scans = pdfs
          .where((f) => !(f['name'] as String).endsWith('_text.pdf'))
          .toList();
      final pool = scans.isEmpty ? pdfs : scans;
      Map<String, dynamic>? pick;
      if (words.isNotEmpty) {
        for (final f in pool) {
          final lower = (f['name'] as String).toLowerCase();
          if (words.every((w) => lower.contains(w))) {
            pick = f;
            break;
          }
        }
      }
      pick ??= pool.firstWhere(
        (f) => f['name'] == '$iaId.pdf',
        orElse: () => pool.reduce(
          (a, b) =>
              ((a['size'] as num?) ?? 0) >= ((b['size'] as num?) ?? 0)
                  ? a
                  : b,
        ),
      );
      final name = pick['name'] as String;
      return 'https://archive.org/download/$iaId/${Uri.encodeComponent(name)}';
    }
    return null;
  }

  /// Manga list from MangaDex, most followed first. [search] matches
  /// titles. Covers ride along (`cover_art`); authors/artists too.
  /// Returns null on failure. Never throws.
  Future<CatalogPage?> fetchManga({
    String? search,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    final query = (search == null || search.trim().isEmpty)
        ? ''
        : search.trim();
    if (page == 1 &&
        !forceRefresh &&
        _mangaCache != null &&
        _mangaCacheAt != null &&
        _mangaQuery == query &&
        DateTime.now().difference(_mangaCacheAt!) < _cacheTtl) {
      return _mangaCache!;
    }
    _mangaSearchClient?.close();
    final client = _mangaSearchClient = http.Client();
    final titleParam = query.isEmpty
        ? ''
        : '&title=${Uri.encodeQueryComponent(query)}';
    final offset = (page - 1) * _pageSize;
    final uri = Uri.parse(
      '$_mangaBase/manga?limit=$_pageSize&offset=$offset'
      '&includes[]=cover_art&includes[]=author&includes[]=artist'
      '&contentRating[]=safe&contentRating[]=suggestive'
      '&order[followedCount]=desc$titleParam',
    );
    final data = await _getJson(uri, client: client);
    if (data == null) return null;
    final docs = data['data'] as List? ?? <dynamic>[];
    final items = docs
        .whereType<Map<String, dynamic>>()
        .map(CatalogItem.fromMangaDex)
        .whereType<CatalogItem>()
        .toList();
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final result = CatalogPage(
      items: items,
      hasMore: offset + items.length < total,
    );
    if (page == 1) {
      _mangaCache = result;
      _mangaCacheAt = DateTime.now();
      _mangaQuery = query;
    }
    return result;
  }

  /// English chapters for one manga, oldest first. Only chapters
  /// with real pages are returned (licensed titles are just external
  /// links — filtered by [MangaChapter.fromMangaDex]). The list is
  /// cached per manga, so re-opening the same title is instant;
  /// [forceRefresh] skips the cache (the detail screen's reload
  /// button) and writes the fresh list back. Returns null on
  /// failure. Never throws.
  Future<List<MangaChapter>?> fetchMangaChapters(
    String mangaId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _mangaChaptersCache[mangaId];
      if (cached != null) return cached;
    }
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
    _cachePut(
      _mangaChaptersCache,
      mangaId,
      chapters,
      _mangaCacheCap,
    );
    return chapters;
  }

  /// Page image URLs for one manga chapter, from MangaDex's at-home
  /// server. Cached per chapter, so re-opening it is instant.
  /// Returns null when the chapter has no pages on the server (stale
  /// chapter) or the fetch fails. Never throws.
  Future<MangaPages?> fetchMangaPages(String chapterId) async {
    final cached = _mangaPagesCache[chapterId];
    if (cached != null) return cached;
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
    final pages = MangaPages(baseUrl: baseUrl, hash: hash, files: files);
    _cachePut(_mangaPagesCache, chapterId, pages, _mangaCacheCap);
    return pages;
  }

  /// Full plain text for a book. Tries each IA id in order and takes
  /// the first non-empty body (IA answers 302, its normal redirect;
  /// `http` follows it). Retries once per id on timeout. The text is
  /// cached per book, so re-opening it never re-downloads ~700KB.
  /// Returns null when no id yields text. Never throws.
  ///
  /// The usual file is `{id}_djvu.txt`, but not every IA item has
  /// one — some OCR files are named differently, or the item has no
  /// OCR at all. When the direct file fails, the item's metadata
  /// is asked for its actual `.txt` files and the largest one is
  /// tried instead. When every listed copy fails, the work's other
  /// editions are tried too (Open Library's editions list — each
  /// edition has its own IA scan). That is the fix for books whose
  /// chapters "don't load" even though the book is listed: the list
  /// only proves the item exists; the old code only proved one
  /// filename exists.
  Future<String?> fetchFullText(CatalogItem item) async {
    final cached = _fullTextCache[item.id];
    if (cached != null) return cached;
    for (final iaId in item.iaIds) {
      final text = await _downloadTextForIaId(iaId, title: item.title);
      if (text != null) {
        _cachePut(_fullTextCache, item.id, text, _fullTextCacheCap);
        return text;
      }
    }
    // Last resort: other editions of the same work, each with its own
    // IA scan. Capped at 5 — more would keep a failing book loading
    // for minutes (each id costs up to two 90s attempts).
    final workId = item.openLibraryWorkId;
    if (workId != null) {
      final tried = item.iaIds.toSet();
      final editionIds = (await _fetchEditionIaIds(workId))
          .where((id) => !tried.contains(id))
          .take(5);
      for (final iaId in editionIds) {
        final text = await _downloadTextForIaId(iaId, title: item.title);
        if (text != null) {
          _cachePut(_fullTextCache, item.id, text, _fullTextCacheCap);
          return text;
        }
      }
    }
    return null;
  }

  /// Tries one IA id: the usual `{id}_djvu.txt` first, then the
  /// item's metadata for its actual `.txt` file. [title] lets the
  /// metadata step pick the file for THIS book when the item holds
  /// several books. Returns the text or null. Never throws.
  Future<String?> _downloadTextForIaId(
    String iaId, {
    String? title,
  }) async {
    final direct = await _downloadText(CatalogItem.textUrlForIa(iaId));
    if (direct != null) return direct;
    return _downloadTextViaMetadata(iaId, title: title);
  }

  /// IA ids of a work's other editions, from Open Library
  /// (`/works/{workId}/editions.json`, each edition's `ocaid` is its
  /// IA item id). Returns an empty list on any failure. Never throws.
  Future<List<String>> _fetchEditionIaIds(String workId) async {
    final data = await _getJson(
      Uri.parse(
        'https://openlibrary.org/works/$workId/editions.json?limit=50',
      ),
    );
    final entries =
        (data?['entries'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            <Map<String, dynamic>>[];
    final ids = <String>[];
    for (final entry in entries) {
      final ocaid = entry['ocaid'] as String?;
      if (ocaid != null && ocaid.isNotEmpty && !ids.contains(ocaid)) {
        ids.add(ocaid);
      }
    }
    return ids;
  }

  /// Downloads one URL as text: 200 + non-empty body, or null.
  /// Retries once on timeout/transport failure; a non-200 answer is
  /// not retried (a 404 stays a 404).
  Future<String?> _downloadText(String url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client.get(Uri.parse(url)).timeout(_textTimeout);
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          return res.body;
        }
        return null;
      } catch (_) {
        if (attempt == 1) return null;
      }
    }
    return null;
  }

  /// Finds the actual plain-text file for one IA item from its
  /// metadata and downloads it. Skips `{id}_djvu.txt` (already tried
  /// directly). A multi-book item (e.g. a series collection) has one
  /// `.txt` per book — the largest file would be the WRONG book, so
  /// when [title] is given, a file whose name holds the title words
  /// wins over the largest file. Returns null when the item has no
  /// text file, the metadata call fails, or the download fails. Never
  /// throws.
  Future<String?> _downloadTextViaMetadata(
    String iaId, {
    String? title,
  }) async {
    final data = await _getJson(
      Uri.parse('https://archive.org/metadata/$iaId'),
    );
    final files =
        (data?['files'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            <Map<String, dynamic>>[];
    final words = title == null ? <String>[] : _titleWords(title);
    String? bestName;
    var bestSize = -1;
    String? bestTitleName;
    var bestTitleSize = -1;
    for (final file in files) {
      final name = file['name'] as String?;
      if (name == null || !name.endsWith('.txt')) continue;
      if (name == '${iaId}_djvu.txt') continue;
      final size = (file['size'] as num?)?.toInt() ?? 0;
      if (size > bestSize) {
        bestSize = size;
        bestName = name;
      }
      if (words.isNotEmpty) {
        final lower = name.toLowerCase();
        if (words.every((w) => lower.contains(w))) {
          if (size > bestTitleSize) {
            bestTitleSize = size;
            bestTitleName = name;
          }
        }
      }
    }
    final pick = bestTitleName ?? bestName;
    if (pick == null) return null;
    final encoded = Uri.encodeComponent(pick);
    return _downloadText('https://archive.org/download/$iaId/$encoded');
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

/// Distinctive words of a book title, for matching IA file names
/// and title searches: lowercased, 3+ letters, minus filler words
/// ("and", "the", "of", ...). "Dog Days" gives [dog, days];
/// "Pride and Prejudice" gives [pride, prejudice].
List<String> _titleWords(String title) {
  const stopwords = {
    'and',
    'the',
    'for',
    'with',
    'from',
    'into',
    'over',
    'under',
  };
  return title
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 3 && !stopwords.contains(w))
      .toList();
}
