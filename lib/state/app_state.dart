/// Global application state — Firebase-backed.
///
/// Mirrors the public API of the previous mock-based implementation so every
/// screen keeps working unchanged, but all data now comes from Firestore via
/// [FirestoreRepository] and auth from [AuthRepository].
///
/// When [DefaultFirebaseConfig.isConfigured] is false (placeholders not yet
/// replaced), [firebaseReady] is false and every repository-touching method
/// no-ops safely instead of crashing.
///
/// Hand-rolled [ChangeNotifier] — no third-party state package required.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/firestore_repository.dart';
import '../firebase/firebase_config.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  AppState() {
    if (!DefaultFirebaseConfig.isConfigured) {
      _firebaseReady = false;
      return;
    }
    _repo = FirestoreRepository();
    _authRepo = AuthRepository();
    _firebaseReady = true;
    _papersSub = _repo!.watchPapers().listen((papers) {
      _papers = papers;
      notifyListeners();
    });
    _authSub = _authRepo!.watchAuthUser().listen(_onAuthUser);
  }

  bool _firebaseReady = false;

  /// True once Firebase config is present and the repositories are live.
  bool get firebaseReady => _firebaseReady;

  FirestoreRepository? _repo;
  AuthRepository? _authRepo;

  StreamSubscription<List<Paper>>? _papersSub;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<Set<String>>? _bookmarksSub;
  StreamSubscription<List<ReadEntry>>? _historySub;

  AppUser? _user;
  AppView _view = AppView.library;
  List<Paper> _papers = <Paper>[];
  String? _selectedPaperId;
  Set<String> _bookmarks = <String>{};
  List<ReadEntry> _readingHistory = <ReadEntry>[];
  final List<AppToast> _toasts = [];
  DateTime? _readStart;
  int _toastSeq = 0;

  // ---------------------------------------------------------------- getters

  AppUser? get user => _user;
  AppView get view => _view;
  List<Paper> get papers => _papers;

  /// Resolves the selected paper id against the live [_papers] list so the
  /// returned object is always fresh (streams keep it up to date).
  Paper? get selectedPaper {
    final id = _selectedPaperId;
    if (id == null) return null;
    return paperById(id);
  }

  Set<String> get bookmarks => _bookmarks;
  List<ReadEntry> get readingHistory => _readingHistory;
  List<AppToast> get toasts => _toasts;

  List<Paper> get approvedPapers =>
      _papers.where((p) => p.status == PaperStatus.approved).toList();
  List<Paper> get pendingPapers =>
      _papers.where((p) => p.status == PaperStatus.pending).toList();

  Paper? paperById(String id) {
    for (final p in _papers) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isBookmarked(String paperId) => _bookmarks.contains(paperId);

  // ------------------------------------------------------------------ auth

  void _onAuthUser(AppUser? user) {
    _user = user;
    _cancelUserSubs();
    if (user != null) {
      _bookmarksSub = _repo!.watchBookmarks(user.id).listen((bookmarks) {
        _bookmarks = bookmarks;
        notifyListeners();
      });
      _historySub = _repo!.watchHistory(user.id).listen((history) {
        _readingHistory = history;
        notifyListeners();
      });
    } else {
      _bookmarks = <String>{};
      _readingHistory = <ReadEntry>[];
    }
    notifyListeners();
  }

  void _cancelUserSubs() {
    _bookmarksSub?.cancel();
    _bookmarksSub = null;
    _historySub?.cancel();
    _historySub = null;
  }

  /// Signs in with email and password.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  /// The [AppUser] profile arrives asynchronously via [watchAuthUser].
  Future<String?> signIn({
    required String email,
    required String password,
  }) {
    if (!_firebaseReady) return Future.value('Firebase is not configured.');
    return _authRepo!.signIn(email: email, password: password);
  }

  /// Creates an account with email, password and display name.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  /// The [AppUser] profile arrives asynchronously via [watchAuthUser].
  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
  }) {
    if (!_firebaseReady) return Future.value('Firebase is not configured.');
    return _authRepo!
        .signUp(username: username, email: email, password: password);
  }

  /// Signs the current user out. The auth stream clears the user, bookmarks
  /// and reading history asynchronously.
  Future<void> logout() async {
    if (!_firebaseReady) return;
    await _authRepo!.signOut();
    navigate(AppView.library);
    showToast('Signed out', '👋');
  }

  /// Persists the edited profile to Firestore and reflects it locally right
  /// away (the auth stream only re-emits on auth-state changes).
  Future<void> updateUser(AppUser updated) async {
    if (!_firebaseReady) return;
    await _repo!.updateUser(updated);
    _user = updated;
    notifyListeners();
    showToast('Profile updated!', '✅');
  }

  // ---------------------------------------------------------------- toasts

  void showToast(String message, [String? icon]) {
    final id = 't${DateTime.now().millisecondsSinceEpoch}_${_toastSeq++}';
    _toasts.add(AppToast(id: id, message: message, icon: icon));
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () => dismissToast(id));
  }

  void dismissToast(String id) {
    final before = _toasts.length;
    _toasts.removeWhere((t) => t.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  // ------------------------------------------------------------- navigation

  /// Mirrors `navigate(v)` — records reading time when leaving the reader,
  /// guards profile/admin behind auth.
  void navigate(AppView v, {void Function()? onAuthPrompt}) {
    if (v == AppView.profile && _user == null) {
      onAuthPrompt?.call();
      return;
    }
    if (v == AppView.admin && _user?.isAdmin != true) return;
    _recordReadingTime();
    _view = v;
    if (v != AppView.reader) _selectedPaperId = null;
    notifyListeners();
  }

  /// Mirrors `openPaper(paper)` — bumps views (fire-and-forget) and starts
  /// the read timer. The live papers stream refreshes the view count.
  void openPaper(Paper paper) {
    if (!_firebaseReady) return;
    _recordReadingTime();
    unawaited(_repo!.incrementViews(paper.id));
    _selectedPaperId = paper.id;
    _view = AppView.reader;
    _readStart = DateTime.now();
    notifyListeners();
  }

  void _recordReadingTime() {
    final paper = selectedPaper;
    final start = _readStart;
    final user = _user;
    if (_view == AppView.reader && paper != null && start != null) {
      final seconds = DateTime.now().difference(start).inSeconds;
      if (seconds > 5 && user != null && _firebaseReady) {
        unawaited(_repo!.addHistoryEntry(
          user.id,
          ReadEntry(
            paperId: paper.id,
            readAt: DateTime.now(),
            secondsSpent: seconds,
          ),
        ));
      }
      _readStart = null;
    }
  }

  // --------------------------------------------------------------- reactions

  /// Mirrors `handleReact` — toggles a single emoji reaction per user.
  ///
  /// Reads the user's current reaction from the live stream, then
  /// fire-and-forget writes the toggle (pass `null` to remove).
  void reactToPaper(String paperId, String emoji) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    final paper = paperById(paperId);
    final current = (paper?.reactions[emoji] ?? const []).contains(user.id);
    final toSet = current ? null : emoji;
    unawaited(_repo!.setReaction(paperId, user.id, toSet));
    if (!current) showToast('Reacted $emoji', emoji);
  }

  // ---------------------------------------------------------------- comments

  void addComment(String paperId, String text) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null || text.trim().isEmpty) return;
    final comment = PaperComment(
      id: '', // Firestore assigns the comment document id (auto-ID).
      userId: user.id,
      username: user.username,
      avatar: user.avatar,
      text: text.trim(),
      createdAt: DateTime.now(),
      likes: 0,
      likedBy: const [],
    );
    unawaited(_repo!.addComment(paperId, comment));
    showToast('Comment posted', '💬');
  }

  void toggleCommentLike(String paperId, String commentId) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    unawaited(_repo!.toggleCommentLike(paperId, commentId, user.id));
  }

  // --------------------------------------------------------------- bookmarks

  void toggleBookmark(String paperId) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    final bookmarked = !isBookmarked(paperId);
    unawaited(_repo!.setBookmark(user.id, paperId, bookmarked));
    if (bookmarked) {
      showToast('Paper saved!', '🔖');
    } else {
      showToast('Removed from saved', '🏷️');
    }
  }

  // ------------------------------------------------------------- submissions

  /// Submits a paper for review. The passed paper's `id` is ignored —
  /// Firestore assigns the document id and `status`/`submittedAt` are set
  /// server-side by [FirestoreRepository.submitPaper].
  Future<void> submitPaper(Paper paper) async {
    if (!_firebaseReady) return;
    await _repo!.submitPaper(paper);
    showToast('Paper submitted for review!', '📬');
    navigate(AppView.library);
  }

  // ------------------------------------------------------------------- admin

  void approvePaper(String paperId) {
    if (!_firebaseReady) return;
    unawaited(_repo!.updatePaperStatus(paperId, PaperStatus.approved));
    showToast('Paper approved and published!', '✅');
  }

  void rejectPaper(String paperId, String reason) {
    if (!_firebaseReady) return;
    unawaited(
      _repo!.updatePaperStatus(paperId, PaperStatus.rejected, reason: reason),
    );
    showToast('Paper rejected.', '❌');
  }

  void requestRevision(String paperId, String reason) {
    if (!_firebaseReady) return;
    unawaited(
      _repo!.updatePaperStatus(paperId, PaperStatus.revision, reason: reason),
    );
    showToast('Revision request sent.');
  }

  void archivePaper(String paperId) {
    if (!_firebaseReady) return;
    unawaited(_repo!.updatePaperStatus(paperId, PaperStatus.archived));
    showToast('Paper archived.');
  }

  /// Deletes the paper document and its comments/reactions subcollections.
  /// Other users' bookmark documents pointing at this paper are left orphaned
  /// (acceptable — bookmarks stream only id lists and UI guards missing papers).
  void deletePaper(String paperId) {
    if (!_firebaseReady) return;
    unawaited(_repo!.deletePaper(paperId));
    showToast('Paper deleted', '🗑');
  }

  // -------------------------------------------------------------- lifecycle

  @override
  void dispose() {
    _papersSub?.cancel();
    _authSub?.cancel();
    _cancelUserSubs();
    _repo?.dispose();
    super.dispose();
  }
}
