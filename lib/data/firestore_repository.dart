/// Firestore-backed data repository for arxivpanel.
///
/// All reads stream live data from Cloud Firestore; writes use the standard
/// Firestore API ([FieldValue], transactions, batched writes). Any snapshot
/// error is logged with [debugPrint] and the stream keeps its last good
/// value instead of crashing.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Parses a Firestore timestamp-ish value tolerantly.
DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

/// Today's date as `yyyy-MM-dd`.
String _today() => DateTime.now().toIso8601String().substring(0, 10);

ReadEntry _readEntryFromJson(Map<String, dynamic> json) {
  return ReadEntry(
    paperId: json['paperId'] as String? ?? '',
    readAt: _parseDateTime(json['readAt']),
    secondsSpent: (json['secondsSpent'] as num?)?.toInt() ?? 0,
  );
}

/// Internal feed owned by one [FirestoreRepository.watchPapers] call.
///
/// Fans-in the `papers` collection with each paper's `comments` and
/// `reactions` subcollections, rebuilding [Paper] objects on any change.
class _PaperFeed {
  _PaperFeed(this._firestore) {
    _papersSub = _firestore
        .collection('papers')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen(_onPapers, onError: _logError('papers'));
  }

  final FirebaseFirestore _firestore;
  final StreamController<List<Paper>> _controller =
      StreamController<List<Paper>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _papersSub;
  final Map<String, Map<String, dynamic>> _paperJson = {};
  final Map<String, List<PaperComment>> _comments = {};
  final Map<String, Map<String, List<String>>> _reactions = {};
  final Map<String, List<StreamSubscription<dynamic>>> _paperSubs = {};

  Stream<List<Paper>> get stream => _controller.stream;

  void Function(Object, StackTrace) _logError(String what) {
    return (Object e, StackTrace s) {
      debugPrint('[FirestoreRepository] $what snapshot error: $e');
    };
  }

  void _onPapers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final liveIds = <String>{};
    for (final doc in snapshot.docs) {
      liveIds.add(doc.id);
      _paperJson[doc.id] = doc.data();
      _comments.putIfAbsent(doc.id, () => <PaperComment>[]);
      _reactions.putIfAbsent(doc.id, () => <String, List<String>>{});
      _paperSubs.putIfAbsent(doc.id, () => _subscribePaper(doc.id));
    }
    // Drop subscriptions (and cached state) for papers that disappeared.
    for (final id in _paperSubs.keys.toList()) {
      if (!liveIds.contains(id)) _cancelPaper(id);
    }
    _emit();
  }

  List<StreamSubscription<dynamic>> _subscribePaper(String paperId) {
    final paperRef = _firestore.collection('papers').doc(paperId);
    final commentsSub = paperRef
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
          _comments[paperId] = [
            for (final d in snap.docs) PaperComment.fromJson(d.id, d.data()),
          ];
          _emit();
        }, onError: _logError('comments($paperId)'));
    final reactionsSub = paperRef.collection('reactions').snapshots().listen((
      snap,
    ) {
      final grouped = <String, List<String>>{};
      for (final d in snap.docs) {
        final emoji = d.data()['emoji'] as String?;
        if (emoji == null || emoji.isEmpty) continue;
        grouped.putIfAbsent(emoji, () => <String>[]).add(d.id);
      }
      _reactions[paperId] = grouped;
      _emit();
    }, onError: _logError('reactions($paperId)'));
    return [commentsSub, reactionsSub];
  }

  void _emit() {
    if (_controller.isClosed) return;
    final papers = [
      for (final entry in _paperJson.entries)
        Paper.fromJson(
          entry.key,
          entry.value,
          comments: _comments[entry.key] ?? const [],
          reactions: _reactions[entry.key] ?? const {},
        ),
    ];
    papers.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    _controller.add(papers);
  }

  void _cancelPaper(String id) {
    for (final sub
        in _paperSubs.remove(id) ?? const <StreamSubscription<dynamic>>[]) {
      sub.cancel();
    }
    _paperJson.remove(id);
    _comments.remove(id);
    _reactions.remove(id);
  }

  Future<void> dispose() async {
    for (final id in _paperSubs.keys.toList()) {
      _cancelPaper(id);
    }
    await _papersSub?.cancel();
    _papersSub = null;
    await _controller.close();
  }
}

/// Internal feed owned by one [FirestoreRepository.watchPolls] call.
///
/// Fans-in the `polls` collection with each poll's `options` subcollection
/// and aggregates vote counts from the `votes` subcollection.
class _PollFeed {
  _PollFeed(this._firestore) {
    _pollsSub = _firestore
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(_onPolls, onError: _logError('polls'));
  }

  final FirebaseFirestore _firestore;
  final StreamController<List<Poll>> _controller =
      StreamController<List<Poll>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pollsSub;
  final Map<String, Map<String, dynamic>> _pollJson = {};
  final Map<String, Map<String, Map<String, dynamic>>> _options = {};
  final Map<String, Map<String, String>> _votes =
      {}; // pollId -> uid -> optionId
  final Map<String, List<StreamSubscription<dynamic>>> _pollSubs = {};

  Stream<List<Poll>> get stream => _controller.stream;

  void Function(Object, StackTrace) _logError(String what) {
    return (Object e, StackTrace s) {
      debugPrint('[FirestoreRepository] $what snapshot error: $e');
    };
  }

  void _onPolls(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final liveIds = <String>{};
    for (final doc in snapshot.docs) {
      liveIds.add(doc.id);
      _pollJson[doc.id] = doc.data();
      _options.putIfAbsent(doc.id, () => <String, Map<String, dynamic>>{});
      _votes.putIfAbsent(doc.id, () => <String, String>{});
      _pollSubs.putIfAbsent(doc.id, () => _subscribePoll(doc.id));
    }
    for (final id in _pollSubs.keys.toList()) {
      if (!liveIds.contains(id)) _cancelPoll(id);
    }
    _emit();
  }

  List<StreamSubscription<dynamic>> _subscribePoll(String pollId) {
    final pollRef = _firestore.collection('polls').doc(pollId);
    final optionsSub = pollRef.collection('options').snapshots().listen((snap) {
      _options[pollId] = {for (final d in snap.docs) d.id: d.data()};
      _emit();
    }, onError: _logError('options($pollId)'));
    final votesSub = pollRef.collection('votes').snapshots().listen((snap) {
      _votes[pollId] = {
        for (final d in snap.docs) d.id: d.data()['optionId'] as String? ?? '',
      };
      _emit();
    }, onError: _logError('votes($pollId)'));
    return [optionsSub, votesSub];
  }

  void _emit() {
    if (_controller.isClosed) return;
    final polls = <Poll>[];
    for (final entry in _pollJson.entries) {
      final counts = <String, int>{};
      for (final optionId in (_votes[entry.key] ?? {}).values) {
        if (optionId.isEmpty) continue;
        counts[optionId] = (counts[optionId] ?? 0) + 1;
      }
      final options = [
        for (final opt in (_options[entry.key] ?? {}).entries)
          PollOption.fromJson(opt.key, opt.value, votes: counts[opt.key] ?? 0),
      ];
      polls.add(Poll.fromJson(entry.key, entry.value, options: options));
    }
    polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(polls);
  }

  void _cancelPoll(String id) {
    for (final sub
        in _pollSubs.remove(id) ?? const <StreamSubscription<dynamic>>[]) {
      sub.cancel();
    }
    _pollJson.remove(id);
    _options.remove(id);
    _votes.remove(id);
  }

  Future<void> dispose() async {
    for (final id in _pollSubs.keys.toList()) {
      _cancelPoll(id);
    }
    await _pollsSub?.cancel();
    _pollsSub = null;
    await _controller.close();
  }
}

class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final List<Future<void> Function()> _feedDisposers = [];

  // ------------------------------------------------------------------
  // Papers
  // ------------------------------------------------------------------

  /// Streams all papers ordered by `submittedAt` descending, with each
  /// paper's comments and emoji reactions hydrated from subcollections.
  Stream<List<Paper>> watchPapers() {
    final feed = _PaperFeed(_firestore);
    _feedDisposers.add(feed.dispose);
    return feed.stream;
  }

  /// Increments the paper's view counter atomically.
  Future<void> incrementViews(String paperId) {
    return _firestore.collection('papers').doc(paperId).update({
      'views': FieldValue.increment(1),
    });
  }

  /// Adds a new paper document with `pending` status and a server timestamp.
  Future<void> submitPaper(Paper paper) {
    final data = paper.toJson()
      ..['status'] = PaperStatus.pending.name
      ..['submittedAt'] = FieldValue.serverTimestamp();
    return _firestore.collection('papers').add(data);
  }

  /// Updates a paper's moderation status.
  ///
  /// Sets `rejectionReason` when [reason] is provided, and stamps
  /// `publishedAt` with today's date (`yyyy-MM-dd`) on approval.
  Future<void> updatePaperStatus(
    String paperId,
    PaperStatus status, {
    String? reason,
  }) {
    final data = <String, dynamic>{'status': status.name};
    if (status == PaperStatus.approved) {
      data['publishedAt'] = _today();
    }
    if (reason != null) {
      data['rejectionReason'] = reason;
    }
    return _firestore.collection('papers').doc(paperId).update(data);
  }

  /// Deletes the paper document and every doc in its `comments` and
  /// `reactions` subcollections in a single batch.
  Future<void> deletePaper(String paperId) async {
    final docRef = _firestore.collection('papers').doc(paperId);
    final comments = await docRef.collection('comments').get();
    final reactions = await docRef.collection('reactions').get();
    final batch = _firestore.batch();
    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in reactions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(docRef);
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // Comments & reactions
  // ------------------------------------------------------------------

  /// Adds a comment to `papers/{paperId}/comments` with an auto-generated ID.
  Future<void> addComment(String paperId, PaperComment comment) {
    final data = comment.toJson()..['createdAt'] = FieldValue.serverTimestamp();
    return _firestore
        .collection('papers')
        .doc(paperId)
        .collection('comments')
        .add(data);
  }

  /// Toggles [userId]'s like on a comment inside a transaction.
  Future<void> toggleCommentLike(
    String paperId,
    String commentId,
    String userId,
  ) {
    final ref = _firestore
        .collection('papers')
        .doc(paperId)
        .collection('comments')
        .doc(commentId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? <String, dynamic>{};
      final likedBy =
          (data['likedBy'] as List?)?.whereType<String>().toList() ??
          <String>[];
      var likes = (data['likes'] as num?)?.toInt() ?? likedBy.length;
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likes = likes > 0 ? likes - 1 : 0;
      } else {
        likedBy.add(userId);
        likes += 1;
      }
      transaction.update(ref, {'likedBy': likedBy, 'likes': likes});
    });
  }

  /// Sets the user's reaction, or removes it when [emoji] is null/empty.
  ///
  /// Reactions are stored as `papers/{paperId}/reactions/{userId}` documents
  /// shaped `{emoji, reactedAt}`.
  Future<void> setReaction(String paperId, String userId, String? emoji) {
    final ref = _firestore
        .collection('papers')
        .doc(paperId)
        .collection('reactions')
        .doc(userId);
    if (emoji == null || emoji.isEmpty) {
      return ref.delete();
    }
    return ref.set({'emoji': emoji, 'reactedAt': FieldValue.serverTimestamp()});
  }

  // ------------------------------------------------------------------
  // Bookmarks
  // ------------------------------------------------------------------

  /// Streams the set of bookmarked paper IDs for a user.
  Stream<Set<String>> watchBookmarks(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet())
        .handleError((Object e, StackTrace s) {
          debugPrint('[FirestoreRepository] bookmarks snapshot error: $e');
        });
  }

  /// Adds or removes a bookmark document at `users/{uid}/bookmarks/{paperId}`.
  Future<void> setBookmark(String uid, String paperId, bool bookmarked) {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(paperId);
    if (bookmarked) {
      return ref.set({'bookmarkedAt': FieldValue.serverTimestamp()});
    }
    return ref.delete();
  }

  // ------------------------------------------------------------------
  // Users
  // ------------------------------------------------------------------

  /// Streams the user document at `users/{uid}`, or `null` when missing.
  Stream<AppUser?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (data == null) return null;
          return AppUser.fromJson(doc.id, data);
        })
        .handleError((Object e, StackTrace s) {
          debugPrint('[FirestoreRepository] user snapshot error: $e');
        });
  }

  /// Writes the user document (merged with any existing fields).
  Future<void> updateUser(AppUser user) {
    return _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toJson(), SetOptions(merge: true));
  }

  // ------------------------------------------------------------------
  // Reading history
  // ------------------------------------------------------------------

  /// Streams up to 50 history entries for a user, newest first.
  Stream<List<ReadEntry>> watchHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .orderBy('readAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) _readEntryFromJson(doc.data()),
          ],
        )
        .handleError((Object e, StackTrace s) {
          debugPrint('[FirestoreRepository] history snapshot error: $e');
        });
  }

  /// Appends a reading-history entry for a user.
  Future<void> addHistoryEntry(String uid, ReadEntry entry) {
    return _firestore.collection('users').doc(uid).collection('history').add({
      'paperId': entry.paperId,
      'readAt': Timestamp.fromDate(entry.readAt),
      'secondsSpent': entry.secondsSpent,
    });
  }

  // ------------------------------------------------------------------
  // Polls
  // ------------------------------------------------------------------

  /// Streams polls ordered by `createdAt` descending, each with its options
  /// hydrated from the `options` subcollection and vote counts aggregated
  /// from the `votes` subcollection.
  Stream<List<Poll>> watchPolls() {
    final feed = _PollFeed(_firestore);
    _feedDisposers.add(feed.dispose);
    return feed.stream;
  }

  /// Records a vote as `polls/{pollId}/votes/{uid}` = `{optionId, votedAt}`.
  Future<void> votePoll(String pollId, String uid, String optionId) {
    return _firestore
        .collection('polls')
        .doc(pollId)
        .collection('votes')
        .doc(uid)
        .set({'optionId': optionId, 'votedAt': FieldValue.serverTimestamp()});
  }

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Cancels every internal subscription started by the watch methods.
  void dispose() {
    for (final disposeFeed in _feedDisposers) {
      unawaited(disposeFeed());
    }
    _feedDisposers.clear();
  }
}
