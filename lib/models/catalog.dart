/// Catalog models for the Browse tabs: e-books, novels, comics, manga
/// from free public sources. Catalog items are NOT papers — they live
/// outside Firestore (fetched from the source API) and only their
/// saves, comments, reactions and reading progress live in Firestore
/// (see FirestoreRepository's catalog methods).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Which catalog tab an item belongs to. [BrowseTab] (models.dart) is
/// the UI tab; this is the data type (no localLibrary here).
enum CatalogType { ebook, novel, comic, manga }

/// One book / comic / manga from a public source. The id is namespaced
/// by source (`ol:OL66554W` for Open Library) so ids never collide
/// across sources. Only the fields the screens show are kept. The
/// search document carries almost everything the detail screen needs
/// — the one exception is an Open Library book's synopsis, which
/// AppState fetches per work when the detail page opens.
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.iaIds,
    this.coverUrl,
    this.pdfUrl,
    this.synopsis,
  });

  final String id;
  final CatalogType type;
  final String title;
  final List<String> authors;
  final List<String> subjects;

  /// Internet Archive item ids with full text, in source order. The
  /// reader tries them in order until one returns non-empty text.
  /// For comics this holds the single issue identifier (the PDF
  /// filename resolves from the item's metadata at open time).
  final List<String> iaIds;

  /// Open Library cover URL (`covers.openlibrary.org`), or null when
  /// the source has no cover — the card then shows a book-icon block.
  final String? coverUrl;

  /// Direct PDF URL for a comic issue, resolved from IA metadata when
  /// the detail screen opens (null until then, and null for books).
  final String? pdfUrl;

  /// Synopsis / description from the source, when the source gives
  /// one: MangaDex and the Internet Archive carry it in the list
  /// response; Open Library needs a per-work fetch (AppState loads it
  /// when the detail page opens). Null means the source has none —
  /// the detail screen says so instead of showing a blank section.
  final String? synopsis;

  CatalogItem copyWith({
    List<String>? iaIds,
    String? pdfUrl,
    String? synopsis,
  }) {
    return CatalogItem(
      id: id,
      type: type,
      title: title,
      authors: authors,
      subjects: subjects,
      iaIds: iaIds ?? this.iaIds,
      coverUrl: coverUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      synopsis: synopsis ?? this.synopsis,
    );
  }

  String get authorLabel =>
      authors.isEmpty ? 'Unknown author' : authors.join(', ');

  /// Plain-text URL for one IA item. IA answers 302 (its normal
  /// redirect); `package:http` follows it.
  static String textUrlForIa(String iaId) =>
      'https://archive.org/download/$iaId/${iaId}_djvu.txt';

  /// Open Library work id (the part after `ol:`), for books. Used to
  /// look up other editions when the listed copies fail to load.
  String? get openLibraryWorkId =>
      id.startsWith('ol:') && id.length > 3 ? id.substring(3) : null;

  /// Builds an e-book or novel from one Open Library search.json
  /// document. Returns null when the document has no usable full text
  /// (`has_fulltext` false or no `ia` ids) — the repo filters those
  /// out. NOTE: `has_fulltext` alone does NOT mean the text is
  /// readable — many IA texts are lending-restricted (401/403 on
  /// download). The repo drops restricted ids with a bulk IA check
  /// before the list reaches the screen.
  static CatalogItem? fromOpenLibrary(
    Map<String, dynamic> json, {
    CatalogType type = CatalogType.ebook,
  }) {
    final hasFullText = json['has_fulltext'] == true;
    final iaIds =
        (json['ia'] as List?)?.whereType<String>().toList() ?? <String>[];
    if (!hasFullText || iaIds.isEmpty) return null;
    final key = json['key'] as String? ?? '';
    final workId = key
        .split('/')
        .lastWhere((part) => part.isNotEmpty, orElse: () => '');
    if (workId.isEmpty) return null;
    final coverId = json['cover_i'];
    return CatalogItem(
      id: 'ol:$workId',
      type: type,
      title: (json['title'] as String? ?? 'Untitled').trim(),
      authors:
          (json['author_name'] as List?)?.whereType<String>().toList() ??
          const [],
      subjects:
          (json['subject'] as List?)?.whereType<String>().take(6).toList() ??
          const [],
      iaIds: iaIds,
      coverUrl: coverId is num
          ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
          : null,
    );
  }

  /// Builds a comic issue from one Internet Archive advancedsearch
  /// document (identifier + title + restriction flag + description).
  /// The cover is IA's thumbnail service; the PDF filename resolves
  /// from the item's metadata when the detail screen opens.
  static CatalogItem? fromInternetArchive(Map<String, dynamic> json) {
    final identifier = json['identifier'] as String?;
    if (identifier == null || identifier.isEmpty) return null;
    return CatalogItem(
      id: 'ia:$identifier',
      type: CatalogType.comic,
      title: (json['title'] as String? ?? identifier).trim(),
      authors: const [],
      subjects: const [],
      iaIds: [identifier],
      coverUrl: 'https://archive.org/services/img/$identifier',
      synopsis: _plainText(json['description'] as String?),
    );
  }

  /// Builds a manga from one MangaDex search document. The title is a
  /// map of localizations — English preferred, otherwise the first
  /// one available. The cover comes from the `cover_art`
  /// relationship (verified live: uploads.mangadex.org serves the
  /// file; HEAD is rejected with 405, GET works).
  static CatalogItem? fromMangaDex(Map<String, dynamic> json) {
    final mangaId = json['id'] as String?;
    if (mangaId == null || mangaId.isEmpty) return null;
    final attr = json['attributes'] as Map<String, dynamic>? ?? {};
    final titles = attr['title'] as Map<String, dynamic>? ?? {};
    final title = (titles['en'] as String?) ??
        (titles.values.whereType<String>().firstOrNull ?? 'Untitled');
    final relationships =
        (json['relationships'] as List?)?.whereType<Map<String, dynamic>>() ??
            const [];
    final authors = <String>[];
    String? coverFile;
    for (final rel in relationships) {
      final relType = rel['type'] as String?;
      final relAttr = rel['attributes'] as Map<String, dynamic>? ?? {};
      if (relType == 'author' || relType == 'artist') {
        final name = relAttr['name'] as String?;
        if (name != null && name.isNotEmpty && !authors.contains(name)) {
          authors.add(name);
        }
      } else if (relType == 'cover_art') {
        coverFile = relAttr['fileName'] as String?;
      }
    }
    final tags = (attr['tags'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((t) =>
                (t['attributes'] as Map<String, dynamic>?)?['name']
                    as Map<String, dynamic>?)
            .map((n) => n?['en'] as String?)
            .whereType<String>()
            .take(6)
            .toList() ??
        const [];
    final descriptions = attr['description'] as Map<String, dynamic>? ?? {};
    final rawSynopsis = (descriptions['en'] as String?) ??
        descriptions.values.whereType<String>().firstOrNull;
    return CatalogItem(
      id: 'md:$mangaId',
      type: CatalogType.manga,
      title: title.trim(),
      authors: authors,
      subjects: tags,
      iaIds: const [],
      coverUrl: coverFile != null
          ? 'https://uploads.mangadex.org/covers/$mangaId/$coverFile'
          : null,
      synopsis: _plainText(rawSynopsis),
    );
  }

}

/// Strips HTML tags from a source description (Internet Archive
/// descriptions often carry a little markup), drops MangaDex's
/// trailing Links section (everything after a `---` divider or a
/// `**Links:**` marker), turns markdown links into plain text, and
/// collapses the whitespace, capped so a huge description does not
/// flood the detail screen. Returns null when nothing readable is
/// left.
String? _plainText(String? raw, {int maxLength = 1500}) {
  if (raw == null) return null;
  var text = raw;
  final divider = text.indexOf('\n---');
  if (divider >= 0) text = text.substring(0, divider);
  final linksAt = text.indexOf('**Links:**');
  if (linksAt >= 0) text = text.substring(0, linksAt);
  text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAll('**', '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  if (text.length > maxLength) {
    text = '${text.substring(0, maxLength).trim()}…';
  }
  return text;
}

/// One manga chapter from MangaDex. Only chapters with real pages are
/// kept — licensed titles return chapters that are just an external
/// link (`externalUrl` set, `pages: 0`) and those are filtered out by
/// [MangaChapter.fromMangaDex].
class MangaChapter {
  const MangaChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.pages,
    this.publishedAt,
  });

  final String id;

  /// Chapter number as the source gives it ("12", "1.5", "" for a
  /// oneshot). Displayed as-is; sorting parses it numerically.
  final String number;
  final String title;
  final int pages;

  /// When MangaDex says this chapter was uploaded (null when the feed
  /// does not carry a date — the chapter still lists, just dateless).
  final DateTime? publishedAt;

  String get label {
    final num = number.isEmpty ? 'Oneshot' : 'Ch. $number';
    return title.isEmpty ? num : '$num — $title';
  }

  static MangaChapter? fromMangaDex(Map<String, dynamic> json) {
    final attr = json['attributes'] as Map<String, dynamic>? ?? {};
    if (attr['externalUrl'] != null) return null;
    final pages = (attr['pages'] as num?)?.toInt() ?? 0;
    if (pages <= 0) return null;
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return MangaChapter(
      id: id,
      number: (attr['chapter'] as String?) ?? '',
      title: (attr['title'] as String? ?? '').trim(),
      pages: pages,
      publishedAt: DateTime.tryParse((attr['publishAt'] as String?) ?? ''),
    );
  }
}

/// Page image URLs for one manga chapter, from MangaDex's at-home
/// server (`/at-home/server/{chapterId}`): `{baseUrl}/data/{hash}/...`.
class MangaPages {
  const MangaPages({
    required this.baseUrl,
    required this.hash,
    required this.files,
  });

  final String baseUrl;
  final String hash;
  final List<String> files;

  List<String> get pageUrls =>
      files.map((f) => '$baseUrl/data/$hash/$f').toList();
}

/// One chapter of a catalog item's full text. [text] is the chapter
/// body (heading line excluded); [startOffset]/[endOffset] are char
/// offsets into the full text, kept for progress bookkeeping.
/// One page of catalog results: the items on this page plus whether
/// the source has more pages after it (from its `numFound` / `total`
/// count, so the tab knows whether to offer Load more).
class CatalogPage {
  const CatalogPage({required this.items, required this.hasMore});

  final List<CatalogItem> items;
  final bool hasMore;
}

class CatalogChapter {
  const CatalogChapter({
    required this.index,
    required this.title,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final int index;
  final String title;
  final String text;
  final int startOffset;
  final int endOffset;
}

/// Splits a book's plain text into chapters. Headings are DETECTED,
/// not guaranteed: a line like `CHAPTER I.` (IA scan text) or
/// `Chapter 1` (Gutenberg text) starts a chapter; the heading line
/// becomes the chapter title. Scan text varies the punctuation
/// (`CHAPTER IX,`, `CHAPTER XVII:`, even `CHAPTER. LV.`), so the
/// pattern accepts `.` `:` `,` `;` or nothing after the number —
/// verified against the real Pride and Prejudice scan: all 61 chapters
/// found, zero missed, zero false positives. Text before the first
/// heading is boilerplate (scan header / license) and is dropped. When
/// no headings match at all, the text is cut into even ~6000-char
/// chunks titled "Part 1..N" (Gutenberg license markers are stripped
/// first when present). Pure function — no I/O, no state.
List<CatalogChapter> splitChapters(String text) {
  final lines = text.split('\n');
  // Char offset of each line's start, so chapters keep offsets into
  // the full text (line length + 1 for the '\n' that split removed).
  final offsets = <int>[];
  var running = 0;
  for (final line in lines) {
    offsets.add(running);
    running += line.length + 1;
  }

  final heading = RegExp(
    r'^\s*(CHAPTER\.?\s+[IVXLCDM]+\s*[.:;,]?|CHAPTER\s+\d+\s*[.:;,]?|Chapter\s+\d+\s*[.:;,]?)\s*$',
  );
  final headingLines = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (heading.hasMatch(lines[i])) headingLines.add(i);
  }

  if (headingLines.isNotEmpty) {
    final chapters = <CatalogChapter>[];
    for (var h = 0; h < headingLines.length; h++) {
      final startLine = headingLines[h];
      final endLine = h + 1 < headingLines.length
          ? headingLines[h + 1]
          : lines.length;
      // Body starts after the heading line; skip blank lines so the
      // chapter text does not open with empty space.
      var bodyStart = startLine + 1;
      while (bodyStart < endLine && lines[bodyStart].trim().isEmpty) {
        bodyStart++;
      }
      final startOffset = bodyStart < endLine
          ? offsets[bodyStart]
          : offsets[startLine];
      final endOffset = endLine < lines.length ? offsets[endLine] : text.length;
      final body = text.substring(startOffset, endOffset).trim();
      if (body.isEmpty) continue;
      chapters.add(
        CatalogChapter(
          index: chapters.length,
          title: lines[startLine].trim(),
          text: body,
          startOffset: startOffset,
          endOffset: endOffset,
        ),
      );
    }
    if (chapters.isNotEmpty) return chapters;
    // Every "chapter" was empty (headings with no body) — fall through
    // to chunking so the book is still readable.
  }

  // No usable headings: strip Gutenberg's license wrapper when present,
  // then cut into even chunks at line boundaries.
  var body = text;
  final startMarker = body.indexOf('*** START OF');
  if (startMarker >= 0) {
    final after = body.indexOf('\n', startMarker);
    if (after >= 0) body = body.substring(after + 1);
  }
  final endMarker = body.indexOf('*** END OF');
  if (endMarker >= 0) body = body.substring(0, endMarker);
  body = body.trim();
  if (body.isEmpty) return const [];
  const chunkSize = 6000;
  final chunks = <CatalogChapter>[];
  var cursor = 0;
  while (cursor < body.length) {
    var end = cursor + chunkSize;
    if (end >= body.length) {
      end = body.length;
    } else {
      // Prefer a line break near the cut so words are not split.
      final breakAt = body.lastIndexOf('\n', end);
      if (breakAt > cursor + chunkSize ~/ 2) end = breakAt;
    }
    chunks.add(
      CatalogChapter(
        index: chunks.length,
        title: 'Part ${chunks.length + 1}',
        text: body.substring(cursor, end).trim(),
        startOffset: cursor,
        endOffset: end,
      ),
    );
    cursor = end;
  }
  return chunks;
}

/// Joins chapters into one continuous text for whole-book reading:
/// each chapter's title as its heading, then its body.
String joinWholeText(List<CatalogChapter> chapters) {
  final out = StringBuffer();
  for (final chapter in chapters) {
    if (out.isNotEmpty) out.write('\n\n');
    out.write(chapter.title);
    out.write('\n\n');
    out.write(chapter.text);
  }
  return out.toString();
}

/// Index of the chapter containing [offset] in [joinWholeText]
/// coordinates. (The join inserts title + blank lines, so chapter
/// spans are computed the same way the join builds them.)
int wholeTextChapterIndex(List<CatalogChapter> chapters, int offset) {
  var cursor = 0;
  for (var i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    final span = chapter.title.length + 2 + chapter.text.length;
    final next = cursor + span + (i + 1 < chapters.length ? 2 : 0);
    if (offset < next) return i;
    cursor = next;
  }
  return chapters.isEmpty ? 0 : chapters.length - 1;
}

/// Reading progress for one catalog item, stored at
/// `users/{uid}/catalog_progress/{catalogId}`.
class CatalogProgress {
  const CatalogProgress({
    required this.lastChapterIndex,
    required this.lastCharOffset,
    required this.readChapterIndices,
    required this.updatedAt,
    this.wholeBook = false,
    this.bookmarkCharOffset,
    this.bookmarkChapterIndex = 0,
    this.bookmarkWholeBook = false,
  });

  final int lastChapterIndex;

  /// Char offset inside the last-read chapter's text (approximate:
  /// derived from the scroll fraction). When [wholeBook] is true,
  /// the offset is into the joined whole-book text instead.
  final int lastCharOffset;
  final List<int> readChapterIndices;
  final DateTime updatedAt;

  /// True when the saved position is in the whole-book reader rather
  /// than one chapter. Old progress docs have no such field and read
  /// back as chapter mode.
  final bool wholeBook;

  /// User-set bookmark: char offset to jump back to (null = no
  /// bookmark). Separate from the auto-saved position above — the
  /// reader sets it, the detail screen jumps to it and clears it.
  final int? bookmarkCharOffset;

  /// Chapter the bookmark sits in (or the chapter containing the
  /// whole-book offset when [bookmarkWholeBook] is true).
  final int bookmarkChapterIndex;

  /// True when the bookmark was set in whole-book mode.
  final bool bookmarkWholeBook;

  Map<String, dynamic> toJson() => {
    'lastChapterIndex': lastChapterIndex,
    'lastCharOffset': lastCharOffset,
    'readChapterIndices': readChapterIndices,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'wholeBook': wholeBook,
    'bookmarkCharOffset': bookmarkCharOffset,
    'bookmarkChapterIndex': bookmarkChapterIndex,
    'bookmarkWholeBook': bookmarkWholeBook,
  };

  static CatalogProgress fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    DateTime parsedUpdatedAt;
    if (updatedAt is Timestamp) {
      parsedUpdatedAt = updatedAt.toDate();
    } else if (updatedAt is DateTime) {
      parsedUpdatedAt = updatedAt;
    } else {
      parsedUpdatedAt = DateTime.now();
    }
    return CatalogProgress(
      lastChapterIndex: (json['lastChapterIndex'] as num?)?.toInt() ?? 0,
      lastCharOffset: (json['lastCharOffset'] as num?)?.toInt() ?? 0,
      readChapterIndices:
          (json['readChapterIndices'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toList() ??
          const [],
      updatedAt: parsedUpdatedAt,
      wholeBook: json['wholeBook'] as bool? ?? false,
      bookmarkCharOffset: (json['bookmarkCharOffset'] as num?)?.toInt(),
      bookmarkChapterIndex:
          (json['bookmarkChapterIndex'] as num?)?.toInt() ?? 0,
      bookmarkWholeBook: json['bookmarkWholeBook'] as bool? ?? false,
    );
  }
}

/// Last-read page inside one manga chapter (0-based page index).
class MangaChapterProgress {
  const MangaChapterProgress({
    required this.page,
    required this.pages,
    required this.updatedAt,
  });

  final int page;
  final int pages;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'page': page,
    'pages': pages,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static MangaChapterProgress? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final updatedAt = json['updatedAt'];
    final parsedUpdatedAt = updatedAt is Timestamp
        ? updatedAt.toDate()
        : updatedAt is DateTime
            ? updatedAt
            : DateTime.now();
    return MangaChapterProgress(
      page: (json['page'] as num?)?.toInt() ?? 0,
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      updatedAt: parsedUpdatedAt,
    );
  }
}

/// Last-read page per chapter for one manga, stored at
/// `users/{uid}/manga_progress/{mangaCatalogId}` as one doc with a
/// `chapters` map (chapter id -> progress). One doc per manga keeps
/// the chapter list to a single stream.
class MangaProgress {
  const MangaProgress({required this.chapters, required this.updatedAt});

  final Map<String, MangaChapterProgress> chapters;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'chapters': chapters.map((id, p) => MapEntry(id, p.toJson())),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static MangaProgress fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    final parsedUpdatedAt = updatedAt is Timestamp
        ? updatedAt.toDate()
        : updatedAt is DateTime
            ? updatedAt
            : DateTime.now();
    final raw = json['chapters'] as Map? ?? {};
    final chapters = <String, MangaChapterProgress>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final parsed = value is Map
          ? MangaChapterProgress.fromJson(
              Map<String, dynamic>.from(value),
            )
          : null;
      if (parsed != null) chapters[entry.key.toString()] = parsed;
    }
    return MangaProgress(chapters: chapters, updatedAt: parsedUpdatedAt);
  }
}

/// A saved catalog item, stored at `users/{uid}/catalog_saves/{id}`
/// as a SNAPSHOT (title/author/cover/synopsis) so the Library tab
/// renders without re-fetching the source.
class CatalogSave {
  const CatalogSave({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.savedAt,
    this.iaIds = const [],
    this.synopsis,
  });

  final String id;
  final CatalogType type;
  final String title;
  final String author;
  final String? coverUrl;
  final DateTime savedAt;

  /// IA item ids with full text, so a saved book still opens its
  /// chapters without re-fetching the source.
  final List<String> iaIds;

  /// Synopsis snapshot, so a saved item still shows one without
  /// re-fetching the source (old saves have none — null is fine).
  final String? synopsis;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'savedAt': Timestamp.fromDate(savedAt),
    'iaIds': iaIds,
    'synopsis': synopsis,
  };

  static CatalogSave? fromJson(String id, Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = CatalogType.values
        .where((t) => t.name == typeName)
        .firstOrNull;
    if (type == null) return null;
    final savedAt = json['savedAt'];
    DateTime parsedSavedAt;
    if (savedAt is Timestamp) {
      parsedSavedAt = savedAt.toDate();
    } else if (savedAt is DateTime) {
      parsedSavedAt = savedAt;
    } else {
      parsedSavedAt = DateTime.now();
    }
    return CatalogSave(
      id: id,
      type: type,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown author',
      coverUrl: json['coverUrl'] as String?,
      savedAt: parsedSavedAt,
      iaIds: (json['iaIds'] as List?)?.whereType<String>().toList() ?? const [],
      synopsis: json['synopsis'] as String?,
    );
  }
}
