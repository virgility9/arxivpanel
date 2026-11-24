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
/// across sources. Only the fields the screens show are kept — the
/// search document already carries everything the detail screen needs,
/// so there is no separate detail fetch.
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.iaIds,
    this.coverUrl,
  });

  final String id;
  final CatalogType type;
  final String title;
  final List<String> authors;
  final List<String> subjects;

  /// Internet Archive item ids with full text, in source order. The
  /// reader tries them in order until one returns non-empty text.
  final List<String> iaIds;

  /// Open Library cover URL (`covers.openlibrary.org`), or null when
  /// the source has no cover — the card then shows a book-icon block.
  final String? coverUrl;

  String get authorLabel => authors.isEmpty ? 'Unknown author' : authors.join(', ');

  /// Plain-text URL for one IA item. IA answers 302 (its normal
  /// redirect); `package:http` follows it.
  static String textUrlForIa(String iaId) =>
      'https://archive.org/download/$iaId/${iaId}_djvu.txt';

  /// Builds an e-book from one Open Library search.json document.
  /// Returns null when the document has no usable full text
  /// (`has_fulltext` false or no `ia` ids) — the repo filters those out.
  static CatalogItem? fromOpenLibrary(Map<String, dynamic> json) {
    final hasFullText = json['has_fulltext'] == true;
    final iaIds =
        (json['ia'] as List?)?.whereType<String>().toList() ?? <String>[];
    if (!hasFullText || iaIds.isEmpty) return null;
    final key = json['key'] as String? ?? '';
    final workId = key.split('/').lastWhere(
          (part) => part.isNotEmpty,
          orElse: () => '',
        );
    if (workId.isEmpty) return null;
    final coverId = json['cover_i'];
    return CatalogItem(
      id: 'ol:$workId',
      type: CatalogType.ebook,
      title: (json['title'] as String? ?? 'Untitled').trim(),
      authors: (json['author_name'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      subjects: (json['subject'] as List?)
              ?.whereType<String>()
              .take(6)
              .toList() ??
          const [],
      iaIds: iaIds,
      coverUrl: coverId is num
          ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
          : null,
    );
  }
}

/// One chapter of a catalog item's full text. [text] is the chapter
/// body (heading line excluded); [startOffset]/[endOffset] are char
/// offsets into the full text, kept for progress bookkeeping.
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
      final endOffset = endLine < lines.length
          ? offsets[endLine]
          : text.length;
      final body = text.substring(startOffset, endOffset).trim();
      if (body.isEmpty) continue;
      chapters.add(CatalogChapter(
        index: chapters.length,
        title: lines[startLine].trim(),
        text: body,
        startOffset: startOffset,
        endOffset: endOffset,
      ));
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
    chunks.add(CatalogChapter(
      index: chunks.length,
      title: 'Part ${chunks.length + 1}',
      text: body.substring(cursor, end).trim(),
      startOffset: cursor,
      endOffset: end,
    ));
    cursor = end;
  }
  return chunks;
}

/// Reading progress for one catalog item, stored at
/// `users/{uid}/catalog_progress/{catalogId}`.
class CatalogProgress {
  const CatalogProgress({
    required this.lastChapterIndex,
    required this.lastCharOffset,
    required this.readChapterIndices,
    required this.updatedAt,
  });

  final int lastChapterIndex;

  /// Char offset inside the last-read chapter's text (approximate:
  /// derived from the scroll fraction).
  final int lastCharOffset;
  final List<int> readChapterIndices;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'lastChapterIndex': lastChapterIndex,
        'lastCharOffset': lastCharOffset,
        'readChapterIndices': readChapterIndices,
        'updatedAt': Timestamp.fromDate(updatedAt),
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
      readChapterIndices: (json['readChapterIndices'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toList() ??
          const [],
      updatedAt: parsedUpdatedAt,
    );
  }
}

/// A saved catalog item, stored at `users/{uid}/catalog_saves/{id}`
/// as a SNAPSHOT (title/author/cover) so the Library tab renders
/// without re-fetching the source.
class CatalogSave {
  const CatalogSave({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    this.coverUrl,
    required this.savedAt,
    this.iaIds = const [],
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

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'savedAt': Timestamp.fromDate(savedAt),
        'iaIds': iaIds,
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
      iaIds: (json['iaIds'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }
}
