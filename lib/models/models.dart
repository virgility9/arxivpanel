/// Data models ported from `src/types.ts` of the React source.
///
/// All models are immutable with `copyWith` helpers so state updates can
/// create modified copies, mirroring the spread-update style of the original.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// A registered user of the platform.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.bio,
    required this.joinedAt,
    this.institution,
    this.website,
    this.isAdmin = false,
    this.lastSeenAnnouncementAt,
    this.themeMode,
    this.themeAccent,
    this.hasSeenOnboarding = false,
  });

  final String id;
  final String username;
  final String email;
  final String avatar;
  final String bio;
  final String joinedAt;
  final String? institution;
  final String? website;
  final bool isAdmin;

  /// When this user last opened the Contest tab. Announcements newer
  /// than this timestamp count as unread and ping the Contest tab.
  /// Null means never — everything counts as unread.
  final DateTime? lastSeenAnnouncementAt;

  /// Saved theme, so Settings survive sign-out / sign-in and a fresh
  /// install on another device: mode is 'dark' | 'light', accent is the
  /// accent name ('gold', 'terracotta', ...). Null = never customized —
  /// the app defaults apply.
  final String? themeMode;
  final String? themeAccent;

  /// True once the user has seen (or skipped) the first-time help tour.
  /// False / missing on old accounts, so they get the tour once too.
  final bool hasSeenOnboarding;

  AppUser copyWith({
    String? username,
    String? email,
    String? avatar,
    String? bio,
    String? joinedAt,
    String? institution,
    String? website,
    bool? isAdmin,
    DateTime? lastSeenAnnouncementAt,
    String? themeMode,
    String? themeAccent,
    bool? hasSeenOnboarding,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      joinedAt: joinedAt ?? this.joinedAt,
      institution: institution ?? this.institution,
      website: website ?? this.website,
      isAdmin: isAdmin ?? this.isAdmin,
      lastSeenAnnouncementAt:
          lastSeenAnnouncementAt ?? this.lastSeenAnnouncementAt,
      themeMode: themeMode ?? this.themeMode,
      themeAccent: themeAccent ?? this.themeAccent,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'username': username,
      'email': email,
      'avatar': avatar,
      'bio': bio,
      'joinedAt': joinedAt,
      'institution': institution,
      'website': website,
      'isAdmin': isAdmin,
    };
    // Only write the timestamp when known: a null here would clear the
    // stored value on every profile save.
    if (lastSeenAnnouncementAt != null) {
      data['lastSeenAnnouncementAt'] =
          Timestamp.fromDate(lastSeenAnnouncementAt!);
    }
    // Same rule for the saved theme: only write it when known, so a
    // profile save never clears a theme saved from another device.
    if (themeMode != null) {
      data['themeMode'] = themeMode;
    }
    if (themeAccent != null) {
      data['themeAccent'] = themeAccent;
    }
    // Only write the tour flag once seen: a false here would be a
    // no-op write, and legacy docs simply read as false.
    if (hasSeenOnboarding) {
      data['hasSeenOnboarding'] = true;
    }
    return data;
  }

  /// Builds an [AppUser] from a Firestore user document.
  ///
  /// Tolerates missing keys with sensible defaults so legacy or partial
  /// documents never crash the app.
  static AppUser fromJson(String id, Map<String, dynamic> json) {
    final lastSeen = json['lastSeenAnnouncementAt'];
    DateTime? parsedLastSeen;
    if (lastSeen is Timestamp) {
      parsedLastSeen = lastSeen.toDate();
    } else if (lastSeen is DateTime) {
      parsedLastSeen = lastSeen;
    } else if (lastSeen is String && lastSeen.isNotEmpty) {
      parsedLastSeen = DateTime.tryParse(lastSeen);
    }
    return AppUser(
      id: id,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      joinedAt: json['joinedAt'] as String? ?? '',
      institution: json['institution'] as String?,
      website: json['website'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      lastSeenAnnouncementAt: parsedLastSeen,
      themeMode: json['themeMode'] as String?,
      themeAccent: json['themeAccent'] as String?,
      hasSeenOnboarding: json['hasSeenOnboarding'] as bool? ?? false,
    );
  }
}

/// A comment left on a paper.
class PaperComment {
  const PaperComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.text,
    required this.createdAt,
    required this.likes,
    required this.likedBy,
  });

  final String id;
  final String userId;
  final String username;
  final String avatar;
  final String text;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;

  PaperComment copyWith({String? text, int? likes, List<String>? likedBy}) {
    return PaperComment(
      id: id,
      userId: userId,
      username: username,
      avatar: avatar,
      text: text ?? this.text,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatar': avatar,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  /// Builds a [PaperComment] from a Firestore comment document.
  ///
  /// Accepts [Timestamp], [DateTime], or ISO-8601 [String] for `createdAt`.
  static PaperComment fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    DateTime parsedCreatedAt;
    if (createdAt is Timestamp) {
      parsedCreatedAt = createdAt.toDate();
    } else if (createdAt is DateTime) {
      parsedCreatedAt = createdAt;
    } else if (createdAt is String && createdAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }
    return PaperComment(
      id: id,
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: parsedCreatedAt,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedBy:
          (json['likedBy'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Moderation status of a paper.
enum PaperStatus { pending, approved, rejected, revision, archived }

extension PaperStatusX on PaperStatus {
  String get label {
    switch (this) {
      case PaperStatus.pending:
        return 'Pending review';
      case PaperStatus.approved:
        return 'Approved';
      case PaperStatus.rejected:
        return 'Rejected';
      case PaperStatus.revision:
        return 'Needs revision';
      case PaperStatus.archived:
        return 'Archived';
    }
  }

  static PaperStatus fromName(String name) {
    return PaperStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => PaperStatus.pending,
    );
  }
}

/// A research paper / thesis in the library.
class Paper {
  const Paper({
    required this.id,
    required this.title,
    required this.author,
    required this.authorId,
    required this.authorAvatar,
    required this.abstract,
    required this.field,
    required this.tags,
    required this.coverImage,
    required this.publishedAt,
    required this.pages,
    required this.views,
    required this.reactions,
    required this.comments,
    required this.institution,
    required this.year,
    required this.status,
    required this.submittedAt,
    this.pdfUrl,
    this.rejectionReason,
  });

  final String id;
  final String title;
  final String author;
  final String authorId;
  final String authorAvatar;
  final String abstract;
  final String field;
  final List<String> tags;
  final String coverImage;
  final String publishedAt;
  final int pages;
  final int views;
  final Map<String, List<String>> reactions;
  final List<PaperComment> comments;
  final String? pdfUrl;
  final String institution;
  final String year;
  final PaperStatus status;
  final DateTime submittedAt;
  final String? rejectionReason;

  /// Total number of emoji reactions across all emoji.
  int get totalReactions =>
      reactions.values.fold(0, (total, users) => total + users.length);

  /// The emoji the given user reacted with, if any.
  String? reactionOf(String userId) {
    for (final entry in reactions.entries) {
      if (entry.value.contains(userId)) return entry.key;
    }
    return null;
  }

  /// Estimated read time in minutes (mirrors `Math.ceil(pages * 2.5)`).
  int get readTimeMinutes => (pages * 2.5).ceil();

  Paper copyWith({
    String? title,
    String? author,
    String? authorId,
    String? authorAvatar,
    String? abstract,
    String? field,
    List<String>? tags,
    String? coverImage,
    String? publishedAt,
    int? pages,
    int? views,
    Map<String, List<String>>? reactions,
    List<PaperComment>? comments,
    String? pdfUrl,
    String? institution,
    String? year,
    PaperStatus? status,
    DateTime? submittedAt,
    String? rejectionReason,
  }) {
    return Paper(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      authorId: authorId ?? this.authorId,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      abstract: abstract ?? this.abstract,
      field: field ?? this.field,
      tags: tags ?? this.tags,
      coverImage: coverImage ?? this.coverImage,
      publishedAt: publishedAt ?? this.publishedAt,
      pages: pages ?? this.pages,
      views: views ?? this.views,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      institution: institution ?? this.institution,
      year: year ?? this.year,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  /// Firestore document data for the paper document itself.
  ///
  /// Contains only paper-document fields: comments and reactions live in
  /// subcollections and are not stored here.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'authorId': authorId,
      'authorAvatar': authorAvatar,
      'abstract': abstract,
      'field': field,
      'tags': tags,
      'coverImage': coverImage,
      'publishedAt': publishedAt,
      'pages': pages,
      'views': views,
      'institution': institution,
      'year': year,
      'status': status.name,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'pdfUrl': pdfUrl,
      'rejectionReason': rejectionReason,
    };
  }

  /// Builds a [Paper] from a Firestore paper document.
  ///
  /// [comments] and [reactions] are hydrated separately from the paper's
  /// subcollections and default to empty.
  static Paper fromJson(
    String id,
    Map<String, dynamic> json, {
    List<PaperComment> comments = const [],
    Map<String, List<String>> reactions = const {},
  }) {
    final submittedAt = json['submittedAt'];
    DateTime parsedSubmittedAt;
    if (submittedAt is Timestamp) {
      parsedSubmittedAt = submittedAt.toDate();
    } else if (submittedAt is DateTime) {
      parsedSubmittedAt = submittedAt;
    } else if (submittedAt is String && submittedAt.isNotEmpty) {
      parsedSubmittedAt = DateTime.tryParse(submittedAt) ?? DateTime.now();
    } else {
      parsedSubmittedAt = DateTime.now();
    }
    return Paper(
      id: id,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      abstract: json['abstract'] as String? ?? '',
      field: json['field'] as String? ?? '',
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      coverImage: json['coverImage'] as String? ?? '',
      publishedAt: json['publishedAt'] as String? ?? '',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      reactions: reactions,
      comments: comments,
      pdfUrl: json['pdfUrl'] as String?,
      institution: json['institution'] as String? ?? '',
      year: json['year'] as String? ?? '',
      status: PaperStatusX.fromName(json['status'] as String? ?? ''),
      submittedAt: parsedSubmittedAt,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}

/// One reading session recorded when leaving the reader view.
class ReadEntry {
  const ReadEntry({
    required this.paperId,
    required this.readAt,
    required this.secondsSpent,
  });

  final String paperId;
  final DateTime readAt;
  final int secondsSpent;
}

/// The top-level navigation views (mirrors the `View` union type).
/// Top-level views the shell swaps between. [browse] is the home tab
/// (Browse: Local Library + the read-only catalog tabs); [library] is
/// the user's saved collection (saved papers and catalog items).
enum AppView { browse, library, feed, reader, post, polls, profile, settings, admin, catalogDetail, catalogReader, mangaReader, catalogPdf }

/// Inner tabs of the Browse view. [localLibrary] is the app's own
/// submitted papers; the other four are read-only catalog tabs backed
/// by free public sources (Open Library for e-books — Gutendex joins
/// later when it recovers — MangaDex for manga, Internet Archive for
/// comics).
enum BrowseTab { localLibrary, ebooks, novels, comics, manga }

/// A transient toast notification. [icon] is a solid Material icon
/// (never an emoji: emoji glyphs render as boxes on some Windows fonts).
class AppToast {
  const AppToast({required this.id, required this.message, this.icon});

  final String id;
  final String message;
  final IconData? icon;
}

/// A single answer option inside a [Poll].
class PollOption {
  const PollOption({required this.id, required this.text, this.votes = 0});

  final String id;
  final String text;
  final int votes;

  PollOption copyWith({String? text, int? votes}) {
    return PollOption(
      id: id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  Map<String, dynamic> toJson() {
    return {'text': text};
  }

  /// Builds a [PollOption] from a Firestore option document.
  ///
  /// [votes] is aggregated from the poll's `votes` subcollection rather than
  /// stored on the option document, so it must be supplied by the caller.
  static PollOption fromJson(
    String id,
    Map<String, dynamic> json, {
    int votes = 0,
  }) {
    return PollOption(
      id: id,
      text: json['text'] as String? ?? '',
      votes: (json['votes'] as num?)?.toInt() ?? votes,
    );
  }
}

/// A community poll stored in Firestore under `polls`.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
    this.options = const [],
  });

  final String id;
  final String question;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;
  final List<PollOption> options;

  Poll copyWith({
    String? question,
    String? createdBy,
    DateTime? createdAt,
    bool? isActive,
    List<PollOption>? options,
  }) {
    return Poll(
      id: id,
      question: question ?? this.question,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      options: options ?? this.options,
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  ///
  /// Options live in the poll's `options` subcollection and are not stored
  /// here.
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  /// Builds a [Poll] from a Firestore poll document.
  ///
  /// [options] are hydrated separately from the poll's `options`
  /// subcollection.
  static Poll fromJson(
    String id,
    Map<String, dynamic> json, {
    List<PollOption> options = const [],
  }) {
    final createdAt = json['createdAt'];
    DateTime parsedCreatedAt;
    if (createdAt is Timestamp) {
      parsedCreatedAt = createdAt.toDate();
    } else if (createdAt is DateTime) {
      parsedCreatedAt = createdAt;
    } else if (createdAt is String && createdAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }
    return Poll(
      id: id,
      question: json['question'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: parsedCreatedAt,
      isActive: json['isActive'] as bool? ?? true,
      options: options,
    );
  }
}

/// A news story for the Feed tab.
///
/// Two kinds: live stories fetched from education/science news feeds
/// ([source] is the publisher, [url] opens the article), and admin-posted
/// items stored in Firestore under `news` ([isAdminPosted] is true and
/// [id] is the document id).
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    this.summary = '',
    this.url = '',
    required this.source,
    required this.publishedAt,
    this.imageUrl = '',
    this.isAdminPosted = false,
    this.postedBy = '',
    // Live-feed only (rss2json `author` / `categories`): the first
    // author and primary category of an arXiv paper. Empty for admin
    // posts and for news items, which carry no author.
    this.author = '',
    this.category = '',
  });

  final String id;
  final String title;
  final String summary;
  final String url;
  final String source;
  final DateTime publishedAt;
  final String imageUrl;
  final bool isAdminPosted;
  final String postedBy;
  final String author;
  final String category;

  NewsItem copyWith({
    String? title,
    String? summary,
    String? url,
    String? source,
    DateTime? publishedAt,
    String? imageUrl,
    bool? isAdminPosted,
    String? postedBy,
    String? author,
    String? category,
  }) {
    return NewsItem(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      url: url ?? this.url,
      source: source ?? this.source,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isAdminPosted: isAdminPosted ?? this.isAdminPosted,
      postedBy: postedBy ?? this.postedBy,
      author: author ?? this.author,
      category: category ?? this.category,
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'url': url,
      'source': source,
      'createdBy': postedBy,
      'createdAt': Timestamp.fromDate(publishedAt),
    };
  }

  /// Builds an admin-posted [NewsItem] from a Firestore `news` document.
  static NewsItem fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    DateTime parsed;
    if (createdAt is Timestamp) {
      parsed = createdAt.toDate();
    } else if (createdAt is DateTime) {
      parsed = createdAt;
    } else if (createdAt is String && createdAt.isNotEmpty) {
      parsed = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      parsed = DateTime.now();
    }
    return NewsItem(
      id: id,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? 'Arxiv',
      publishedAt: parsed,
      isAdminPosted: true,
      postedBy: json['createdBy'] as String? ?? '',
    );
  }

  /// Builds a live-feed item from one rss2json item object.
  static NewsItem fromLiveJson(Map<String, dynamic> json, String source) {
    final rawDate = json['pubDate'] as String? ?? '';
    final link = json['link'] as String? ?? '';
    String? thumb;
    final enclosure = json['enclosure'];
    if (enclosure is Map<String, dynamic>) {
      thumb = enclosure['thumbnail'] as String?;
    }
    thumb ??= json['thumbnail'] as String?;
    // rss2json's `author` is the first author for arXiv entries and
    // empty for the news feeds; `categories` holds the arXiv categories
    // (first one is the primary). Both stay empty otherwise.
    final rawCategories = json['categories'];
    final category = rawCategories is List && rawCategories.isNotEmpty
        ? _plainText('${rawCategories.first}')
        : '';
    return NewsItem(
      id: link.isNotEmpty ? link : '$source:${json['guid'] ?? ''}',
      title: _plainText(json['title'] as String? ?? ''),
      summary: _plainText(json['description'] as String? ?? ''),
      url: link,
      source: source,
      publishedAt: DateTime.tryParse(rawDate) ?? DateTime.now(),
      imageUrl: thumb ?? '',
      author: _plainText(json['author'] as String? ?? ''),
      category: category,
    );
  }

  /// Sharp version of a feed thumbnail.
  ///
  /// Phys.org's rss2json thumbnails are 90x90 (`/csz/news/tmb/`) — stretched
  /// to a full-width cover they blur. The same file exists at 800px wide
  /// under `/csz/news/800/` (verified live on the whole current feed), so
  /// the cover uses that. Any other URL is returned unchanged.
  static String hiResImageUrl(String url) {
    const marker = '/csz/news/tmb/';
    if (!url.contains(marker)) return url;
    return url.replaceFirst(marker, '/csz/news/800/');
  }

  /// Strips HTML tags and common entities from a feed summary.
  static String _plainText(String raw) {
    var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// An announcement shown at the top of the Contest tab.
///
/// Two kinds share this shape:
/// * `general` — posted by an admin to `announcements`, seen by everyone.
/// * `paper` — a paper-status notice for one author, stored under
///   `users/{uid}/notifications` so only that author (and admins) can
///   read it. `paperStatus` is `approved`, `rejected` or `revision`.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.body = '',
    required this.createdAt,
    this.createdBy = '',
    this.kind = 'general',
    this.paperId,
    this.paperTitle,
    this.paperStatus,
    this.targetUserId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String createdBy;

  /// `general` or `paper`.
  final String kind;
  final String? paperId;
  final String? paperTitle;
  final String? paperStatus;
  final String? targetUserId;

  bool get isPaperStatus => kind == 'paper';

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'kind': kind,
      'paperId': paperId,
      'paperTitle': paperTitle,
      'paperStatus': paperStatus,
      'targetUserId': targetUserId,
    };
  }

  static Announcement fromJson(String id, Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    DateTime parsed;
    if (createdAt is Timestamp) {
      parsed = createdAt.toDate();
    } else if (createdAt is DateTime) {
      parsed = createdAt;
    } else if (createdAt is String && createdAt.isNotEmpty) {
      parsed = DateTime.tryParse(createdAt) ?? DateTime.now();
    } else {
      parsed = DateTime.now();
    }
    return Announcement(
      id: id,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: parsed,
      createdBy: json['createdBy'] as String? ?? '',
      kind: json['kind'] as String? ?? 'general',
      paperId: json['paperId'] as String?,
      paperTitle: json['paperTitle'] as String?,
      paperStatus: json['paperStatus'] as String?,
      targetUserId: json['targetUserId'] as String?,
    );
  }
}

/// The latest app version the devs published, stored in Firestore at
/// A published release: the latest version from GitHub Releases, so no
/// Play Store is needed and no admin form has to publish it.
///
/// The release is created with `scripts/release.ps1` after
/// `flutter build apk --release`. The app compares [latestVersion] with
/// the version it was built with and shows an Update / Later prompt
/// when a newer one exists. [notes] is the release body (What's New).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    this.downloadUrl = '',
    this.notes = '',
    required this.updatedAt,
  });

  final String latestVersion;
  final String downloadUrl;
  final String notes;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'latestVersion': latestVersion,
      'downloadUrl': downloadUrl,
      'notes': notes,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static AppUpdateInfo fromJson(String id, Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'];
    DateTime parsed;
    if (updatedAt is Timestamp) {
      parsed = updatedAt.toDate();
    } else if (updatedAt is DateTime) {
      parsed = updatedAt;
    } else if (updatedAt is String && updatedAt.isNotEmpty) {
      parsed = DateTime.tryParse(updatedAt) ?? DateTime.now();
    } else {
      parsed = DateTime.now();
    }
    return AppUpdateInfo(
      latestVersion: json['latestVersion'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      updatedAt: parsed,
    );
  }

  /// True when [latestVersion] is newer than [current] (`1.2.0` beats
  /// `1.1.9`; missing parts count as 0; build numbers after `+` are
  /// ignored). Non-numeric parts compare as 0 so a bad value can never
  /// crash the check.
  bool isNewerThan(String current) {
    if (latestVersion.trim().isEmpty) return false;
    List<int> parse(String v) {
      final core = v.trim().split('+').first;
      return core
          .split('.')
          .map((p) => int.tryParse(p.trim()) ?? 0)
          .toList();
    }

    final latest = parse(latestVersion);
    final cur = parse(current);
    final len = latest.length > cur.length ? latest.length : cur.length;
    for (var i = 0; i < len; i++) {
      final l = i < latest.length ? latest[i] : 0;
      final c = i < cur.length ? cur[i] : 0;
      if (l != c) return l > c;
    }
    return false;
  }
}
