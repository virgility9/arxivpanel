/// Data models ported from `src/types.ts` of the React source.
///
/// All models are immutable with `copyWith` helpers so state updates can
/// create modified copies, mirroring the spread-update style of the original.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

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

  AppUser copyWith({
    String? username,
    String? email,
    String? avatar,
    String? bio,
    String? joinedAt,
    String? institution,
    String? website,
    bool? isAdmin,
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
    );
  }

  /// Firestore document data (id is the document id, excluded here).
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'avatar': avatar,
      'bio': bio,
      'joinedAt': joinedAt,
      'institution': institution,
      'website': website,
      'isAdmin': isAdmin,
    };
  }

  /// Builds an [AppUser] from a Firestore user document.
  ///
  /// Tolerates missing keys with sensible defaults so legacy or partial
  /// documents never crash the app.
  static AppUser fromJson(String id, Map<String, dynamic> json) {
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

  /// Deep copy used when seeding state from the mock dataset.
  Paper deepCopy() {
    return copyWith(
      tags: List<String>.of(tags),
      reactions: {
        for (final e in reactions.entries) e.key: List<String>.of(e.value),
      },
      comments: comments
          .map((c) => c.copyWith(likedBy: List<String>.of(c.likedBy)))
          .toList(),
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
enum AppView { library, reader, post, polls, profile, settings, admin }

/// A transient toast notification.
class AppToast {
  const AppToast({required this.id, required this.message, this.icon});

  final String id;
  final String message;
  final String? icon;
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
