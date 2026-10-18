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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/cloudinary_config.dart';
import '../data/cloudinary_repository.dart';
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
    _cloudinaryRepo = CloudinaryRepository();
    _firebaseReady = true;
    _subscribePapers();
    _usersSub = _repo!.watchUsers().listen((users) {
      _users = users;
      _usersLoaded = true;
      notifyListeners();
    });
    _subscribeAuth();
  }

  /// Subscribes to the auth stream, resubscribing on error. If this stream
  /// dies, sign-in/out events never reach the UI (sign-out still appears to
  /// work because [logout] clears state manually) until a page refresh.
  void _subscribeAuth() {
    _authSub = _authRepo!.watchAuthUser().listen(
          _onAuthUser,
          onError: _onAuthError,
        );
  }

  void _onAuthError(Object e, StackTrace s) {
    debugPrint('[AppState] auth stream error, resubscribing: $e');
    _authSub?.cancel();
    _authSub = null;
    // Brief delay to avoid hot-looping on persistent failures.
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed && _authRepo != null) _subscribeAuth();
    });
  }

  bool _disposed = false;

  bool _firebaseReady = false;

  /// True once Firebase config is present and the repositories are live.
  bool get firebaseReady => _firebaseReady;

  FirestoreRepository? _repo;
  AuthRepository? _authRepo;
  CloudinaryRepository? _cloudinaryRepo;

  StreamSubscription<List<Paper>>? _papersSub;

  /// Disposer for the feed behind [_papersSub]; called when re-subscribing
  /// so the old feed's query and per-paper listeners don't leak.
  Future<void> Function()? _papersDispose;

  /// Which papers query [_papersSub] is currently on. The feed must follow
  /// the user's admin flag: admins get the unfiltered collection (allowed by
  /// the rules' `isAdmin()` branch), everyone else gets approved papers only
  /// (an unfiltered query would be denied for them — rules are not filters).
  bool _papersAdmin = false;

  /// True after the admin papers query was denied by the rules — i.e. the app
  /// believes the user is an admin but Firestore doesn't (missing
  /// `admins/{uid}` doc). While set, we stay on the public approved-only feed
  /// instead of retrying a query that can never succeed. Reset whenever the
  /// signed-in account changes, so a later console fix is picked up.
  bool _papersAdminDenied = false;

  /// (Re)subscribes to the papers feed matching the current admin status.
  /// Called once at startup and again whenever the auth user (and thus
  /// `isAdmin`) resolves or changes. `_papersLoaded` is intentionally left
  /// alone on re-subscribe so the UI keeps showing the previous feed until
  /// the new one emits, instead of flashing a loading spinner.
  void _subscribePapers() {
    if (_repo == null) return;
    final admin = _user?.isAdmin == true && !_papersAdminDenied;
    if (_papersSub != null && _papersAdmin == admin) return;
    _papersSub?.cancel();
    // Fire-and-forget: teardown is idempotent and never throws.
    unawaited(_papersDispose?.call());
    _papersAdmin = admin;
    final feed = _repo!.watchPapers(admin: admin);
    _papersDispose = feed.dispose;
    _papersSub = feed.stream.listen(
      (papers) {
        _papers = papers;
        _papersLoaded = true;
        notifyListeners();
      },
      onError: _onPapersError,
    );
  }

  void _onPapersError(Object e) {
    // Half-admin state: the admin query was denied, so fall back to the
    // public feed — the library keeps working instead of spinning on
    // "Loading the archive…" forever. Admin-only actions still surface
    // their own failures via toasts.
    if (_papersAdmin && !_papersAdminDenied && _isPermissionDenied(e)) {
      _papersAdminDenied = true;
      debugPrint(
        '[AppState] admin papers query denied; falling back to public feed',
      );
      _papersSub?.cancel();
      _papersSub = null;
      _subscribePapers();
      return;
    }
    debugPrint('[AppState] papers stream error: $e');
  }

  bool _isPermissionDenied(Object e) =>
      e is FirebaseException && e.code == 'permission-denied';

  StreamSubscription<List<AppUser>>? _usersSub;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<Set<String>>? _bookmarksSub;
  StreamSubscription<List<ReadEntry>>? _historySub;

  AppUser? _user;
  AppView _view = AppView.library;
  List<Paper> _papers = <Paper>[];
  bool _papersLoaded = false;
  List<AppUser> _users = <AppUser>[];
  bool _usersLoaded = false;
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

  /// True once the papers stream has emitted at least once. Screens render a
  /// loading indicator until [papersResolved] so users never see a flash of
  /// "no papers" on first load.
  bool get papersResolved => _papersLoaded || !_firebaseReady;

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

  /// All registered users (admin console). Empty until the users stream
  /// emits; see [usersResolved].
  List<AppUser> get users => _users;

  /// True once the users stream has emitted at least once.
  bool get usersResolved => _usersLoaded || !_firebaseReady;

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

  /// Bounded retries for the per-user streams. A transient failure (e.g. an
  /// auth-token race at startup) used to kill bookmarks/history silently for
  /// the rest of the session; now we retry a few times, then surface a toast
  /// instead of dying quietly.
  static const _maxUserDataRetries = 3;
  int _userDataRetries = 0;

  void _onAuthUser(AppUser? user) {
    debugPrint('[AppState] auth user: ${user?.id ?? 'signed out'}');
    final accountChanged = _user?.id != user?.id;
    _user = user;
    _cancelUserSubs();
    _userDataRetries = 0;
    // Re-probe admin query access for a new account: a console fix made
    // after a fallback should take effect on next sign-in.
    if (accountChanged) _papersAdminDenied = false;
    // The papers feed depends on isAdmin — re-subscribe if it changed.
    _subscribePapers();
    if (user != null) {
      _subscribeUserData(user);
    } else {
      _bookmarks = <String>{};
      _readingHistory = <ReadEntry>[];
    }
    notifyListeners();
  }

  void _subscribeUserData(AppUser user) {
    _bookmarksSub = _repo!.watchBookmarks(user.id).listen(
      (bookmarks) {
        _bookmarks = bookmarks;
        _userDataRetries = 0;
        notifyListeners();
      },
      onError: (Object e, StackTrace s) =>
          _retryUserData(user, 'bookmarks', e),
    );
    _historySub = _repo!.watchHistory(user.id).listen(
      (history) {
        _readingHistory = history;
        _userDataRetries = 0;
        notifyListeners();
      },
      onError: (Object e, StackTrace s) => _retryUserData(user, 'history', e),
    );
  }

  void _retryUserData(AppUser user, String what, Object e) {
    // Signed out or switched accounts while waiting — nothing to retry.
    if (_user?.id != user.id) return;
    debugPrint('[AppState] $what snapshot error, retrying: $e');
    if (_userDataRetries >= _maxUserDataRetries) {
      showToast(
        'Could not load your saved data. Restart the app to try again.',
        '⚠️',
      );
      return;
    }
    _userDataRetries++;
    _cancelUserSubs();
    Future.delayed(const Duration(seconds: 3), () {
      if (_user?.id == user.id) _subscribeUserData(user);
    });
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

  /// Sends a password-reset email.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  Future<String?> sendPasswordReset({required String email}) {
    if (!_firebaseReady) return Future.value('Firebase is not configured.');
    return _authRepo!.sendPasswordReset(email: email);
  }

  /// Signs the current user out. Local auth state is cleared synchronously
  /// here instead of waiting on the auth stream, so the UI updates even if
  /// Firebase's sign-out or the stream round-trip fails or is delayed.
  /// (A later auth-stream event is harmless — [_onAuthUser] with null is
  /// idempotent.)
  Future<void> logout() async {
    if (!_firebaseReady) return;
    try {
      await _authRepo!.signOut();
    } catch (e) {
      debugPrint('[AppState] signOut failed: $e');
    }
    _user = null;
    _cancelUserSubs();
    _bookmarks = <String>{};
    _readingHistory = <ReadEntry>[];
    _subscribePapers();
    navigate(AppView.library);
    notifyListeners();
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
    // Admins do admin tasks only — they cannot open the submit-paper form.
    if (v == AppView.post && _user?.isAdmin == true) return;
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
  /// server-side by [FirestoreRepository.submitPaper]. Returns the new
  /// document id (so the caller can upload the paper's PDF), or null when
  /// Firebase isn't configured.
  Future<String?> submitPaper(Paper paper) async {
    if (!_firebaseReady) return null;
    final id = await _repo!.submitPaper(paper);
    showToast('Paper submitted for review!', '📬');
    // NOTE: no navigate() here — the post screen shows its own success
    // state with a "Back to Library" button.
    return id;
  }

  /// Attaches an uploaded PDF's URL and its auto-generated cover (the
  /// PDF's first page) to a paper.
  Future<bool> setPaperPdfAndCover(
    String paperId,
    String pdfUrl,
    String coverUrl,
  ) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.setPaperPdfAndCover(paperId, pdfUrl, coverUrl);
      return true;
    } catch (e) {
      debugPrint('setPaperPdfAndCover failed: $e');
      showToast('Could not attach the PDF.', '⚠️');
      return false;
    }
  }

  /// Uploads a paper PDF to Cloudinary (free tier, no Blaze billing needed).
  /// Returns the file URL and the auto-generated cover (the PDF's first
  /// page), or null when the upload failed or Cloudinary isn't configured
  /// yet (see `lib/data/cloudinary_config.dart`).
  Future<({String fileUrl, String coverUrl})?> uploadPaperPdf(
    Uint8List bytes,
    String fileName,
  ) async {
    if (!CloudinaryConfig.isConfigured) {
      showToast(
        'PDF uploads need a free Cloudinary setup first — see the setup guide.',
        '⚠️',
      );
      return null;
    }
    try {
      final uploaded = await _cloudinaryRepo!.uploadPdf(bytes, fileName);
      return (
        fileUrl: uploaded.fileUrl,
        coverUrl: CloudinaryRepository.firstPageCover(uploaded.publicId),
      );
    } catch (e) {
      debugPrint('PDF upload failed: $e');
      showToast('PDF upload failed. Try again.', '⚠️');
      return null;
    }
  }

  // ------------------------------------------------------------------- admin

  /// Approves a paper. Returns true when Firestore accepted the write;
  /// surfaces a toast either way so a rejected write (e.g. unpublished
  /// rules) can never look like a success.
  Future<bool> approvePaper(String paperId) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.updatePaperStatus(paperId, PaperStatus.approved);
      showToast('Paper approved and published!', '✅');
      return true;
    } catch (e) {
      debugPrint('approvePaper failed: $e');
      showToast('Could not approve the paper.', '⚠️');
      return false;
    }
  }

  Future<bool> rejectPaper(String paperId, String reason) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.updatePaperStatus(paperId, PaperStatus.rejected,
          reason: reason);
      showToast('Paper rejected.', '❌');
      return true;
    } catch (e) {
      debugPrint('rejectPaper failed: $e');
      showToast('Could not reject the paper.', '⚠️');
      return false;
    }
  }

  Future<bool> requestRevision(String paperId, String reason) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.updatePaperStatus(paperId, PaperStatus.revision,
          reason: reason);
      showToast('Revision request sent.');
      return true;
    } catch (e) {
      debugPrint('requestRevision failed: $e');
      showToast('Could not send the revision request.', '⚠️');
      return false;
    }
  }

  Future<bool> archivePaper(String paperId) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.updatePaperStatus(paperId, PaperStatus.archived);
      showToast('Paper archived.');
      return true;
    } catch (e) {
      debugPrint('archivePaper failed: $e');
      showToast('Could not archive the paper.', '⚠️');
      return false;
    }
  }

  /// Deletes the paper document and its comments/reactions subcollections.
  /// Other users' bookmark documents pointing at this paper are left orphaned
  /// (acceptable — bookmarks stream only id lists and UI guards missing papers).
  Future<bool> deletePaper(String paperId) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.deletePaper(paperId);
      showToast('Paper deleted', '🗑');
      return true;
    } catch (e) {
      debugPrint('deletePaper failed: $e');
      showToast('Could not delete the paper.', '⚠️');
      return false;
    }
  }

  /// Deletes a user profile (admin only per `firestore.rules`). The user's
  /// papers are kept. Returns false — and toasts — when the write is
  /// rejected.
  Future<bool> deleteUser(String uid) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.deleteUser(uid);
      showToast('User deleted', '🗑');
      return true;
    } catch (e) {
      debugPrint('deleteUser failed: $e');
      showToast('Could not delete the user.', '⚠️');
      return false;
    }
  }

  // -------------------------------------------------------------- lifecycle

  @override
  void dispose() {
    _disposed = true;
    _papersSub?.cancel();
    _usersSub?.cancel();
    _authSub?.cancel();
    _cancelUserSubs();
    _repo?.dispose();
    super.dispose();
  }
}
