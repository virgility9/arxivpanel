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
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_repository.dart';
import '../data/catalog_repository.dart';
import '../data/cloudinary_config.dart';
import '../data/cloudinary_repository.dart';
import '../data/constants.dart';
import '../data/firestore_repository.dart';
import '../data/news_repository.dart';
import '../firebase/firebase_config.dart';
import '../models/catalog.dart';
import '../models/models.dart';
import '../services/app_updater.dart';
import '../services/github_update.dart';

/// The app's connection health, derived from the papers stream: `online`
/// once data flows, `slow` when the first emission takes over 8 seconds,
/// `offline` when the stream fails with a network error.
enum ConnectionStatus { online, slow, offline }

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
    _newsSub = _repo!.watchNews().listen(
      (news) {
        _adminNews = news;
        _adminNewsLoaded = true;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[AppState] news stream error: $e');
      },
    );
    _subscribeAnnouncements();
    unawaited(checkForUpdate());
  }

  /// Subscribes to the public announcements feed (Contest tab).
  void _subscribeAnnouncements() {
    if (_repo == null) return;
    _announcementsSub = _repo!.watchAnnouncements().listen(
      (items) {
        _announcements = items;
        _announcementsLoaded = true;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[AppState] announcements stream error: $e');
      },
    );
  }

  /// Subscribes to one user's paper-status notifications. A notice that
  /// arrives after the first emission — i.e. while the app is open —
  /// also shows as a toast, so the author sees it without opening the
  /// Contest tab. The first emission is the backlog, never toasted.
  void _subscribeMyNotifications(String uid) {
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _notificationsFirstEmission = true;
    _notificationsSub = _repo!
        .watchMyNotifications(uid)
        .listen(
          (items) {
            if (!_notificationsFirstEmission) {
              final known = _myNotifications.map((n) => n.id).toSet();
              for (final n in items) {
                if (!known.contains(n.id)) {
                  showToast(n.title, Icons.campaign);
                }
              }
            }
            _notificationsFirstEmission = false;
            _myNotifications = items;
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('[AppState] notifications stream error: $e');
          },
        );
  }

  void _cancelNotificationSub() {
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _myNotifications = <Announcement>[];
    _notificationsFirstEmission = true;
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

  /// The signed-in author's own papers in every status. Non-admins only
  /// load approved papers in [_papers], so without this their pending /
  /// rejected submissions would never appear on the profile.
  StreamSubscription<List<Paper>>? _ownSub;
  Future<void> Function()? _ownDispose;
  List<Paper> _ownPapers = <Paper>[];
  String? _ownUid;

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
    _syncOwnPapers(admin);
    if (_papersSub != null && _papersAdmin == admin) return;
    _papersSub?.cancel();
    // Fire-and-forget: teardown is idempotent and never throws.
    unawaited(_papersDispose?.call());
    _papersAdmin = admin;
    final feed = _repo!.watchPapers(admin: admin);
    _papersDispose = feed.dispose;
    _papersSub = feed.stream.listen((papers) {
      _papers = papers;
      _papersLoaded = true;
      _connectionStatus = ConnectionStatus.online;
      _slowTimer?.cancel();
      notifyListeners();
    }, onError: _onPapersError);
    // No first emission after 8s on a slow connection — say so instead of
    // spinning on "Loading the archive…" forever.
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (!_papersLoaded && !_disposed) {
        _connectionStatus = ConnectionStatus.slow;
        notifyListeners();
      }
    });
  }

  /// Keeps the own-papers feed in step with the signed-in user. Admins
  /// already receive every paper through the main feed, so they skip it.
  void _syncOwnPapers(bool admin) {
    final uid = (!admin && _user != null) ? _user!.id : null;
    if (uid == _ownUid) return;
    _ownSub?.cancel();
    _ownSub = null;
    unawaited(_ownDispose?.call());
    _ownDispose = null;
    _ownUid = uid;
    if (_ownPapers.isNotEmpty) {
      _ownPapers = <Paper>[];
      notifyListeners();
    }
    if (uid == null) return;
    final feed = _repo!.watchOwnPapers(uid);
    _ownDispose = feed.dispose;
    _ownSub = feed.stream.listen((papers) {
      _ownPapers = papers;
      notifyListeners();
    }, onError: (Object e) => debugPrint('[AppState] own papers error: $e'));
  }

  /// The signed-in user's papers in every status, newest submission first.
  List<Paper> get myPapers {
    final uid = _user?.id;
    if (uid == null) return const <Paper>[];
    final byId = <String, Paper>{
      for (final p in _papers)
        if (p.authorId == uid) p.id: p,
      for (final p in _ownPapers) p.id: p,
    };
    final list = byId.values.toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
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
    if (!_isPermissionDenied(e)) {
      _connectionStatus = ConnectionStatus.offline;
      _slowTimer?.cancel();
      notifyListeners();
    }
    debugPrint('[AppState] papers stream error: $e');
  }

  bool _isPermissionDenied(Object e) =>
      e is FirebaseException && e.code == AppConstants.permissionDeniedCode;

  /// Re-subscribes to the papers feed after a slow/offline state (the
  /// Library's Retry button). Keeps already-loaded papers on screen.
  void retryConnection() {
    if (_repo == null) return;
    _connectionStatus = ConnectionStatus.online;
    _papersSub?.cancel();
    _papersSub = null;
    // Fire-and-forget: teardown is idempotent and never throws.
    unawaited(_papersDispose?.call());
    _papersDispose = null;
    _subscribePapers();
    notifyListeners();
  }

  StreamSubscription<List<AppUser>>? _usersSub;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<Set<String>>? _bookmarksSub;
  StreamSubscription<List<ReadEntry>>? _historySub;
  StreamSubscription<List<NewsItem>>? _newsSub;
  StreamSubscription<List<Announcement>>? _announcementsSub;
  StreamSubscription<List<Announcement>>? _notificationsSub;

  /// Connection health (see [ConnectionStatus]). Starts `online`; the
  /// slow timer in [_subscribePapers] flips it to `slow`, and a network
  /// papers error flips it to `offline`. A fresh emission flips it back.
  ConnectionStatus _connectionStatus = ConnectionStatus.online;
  Timer? _slowTimer;

  final NewsRepository _newsRepo = NewsRepository();

  // ------------------------------------------------------------ catalog
  final CatalogRepository _catalogRepo = CatalogRepository();
  List<CatalogItem> _ebooks = <CatalogItem>[];
  bool _ebooksLoading = false;
  bool _ebooksError = false;
  String _ebooksQuery = '';
  CatalogItem? _selectedCatalogItem;
  List<CatalogChapter> _catalogChapters = <CatalogChapter>[];
  int _selectedChapterIndex = 0;
  bool _catalogTextLoading = false;
  bool _catalogTextError = false;
  List<PaperComment> _catalogComments = <PaperComment>[];
  Set<String> _catalogLikedBy = <String>{};
  List<CatalogSave> _catalogSaves = <CatalogSave>[];
  CatalogProgress? _catalogProgress;
  StreamSubscription<List<PaperComment>>? _catalogCommentsSub;
  StreamSubscription<Set<String>>? _catalogReactionsSub;
  StreamSubscription<CatalogProgress?>? _catalogProgressSub;
  StreamSubscription<List<CatalogSave>>? _catalogSavesSub;
  List<NewsItem> _adminNews = <NewsItem>[];
  bool _adminNewsLoaded = false;
  List<NewsItem> _liveNews = <NewsItem>[];
  bool _liveNewsLoading = false;
  bool _liveNewsError = false;
  List<NewsItem> _arxivPapers = <NewsItem>[];
  bool _arxivPapersLoading = false;
  bool _arxivPapersError = false;

  /// Admin announcements (public) + the signed-in user's paper-status
  /// notices (private). Merged in [allAnnouncements], newest first.
  List<Announcement> _announcements = <Announcement>[];
  bool _announcementsLoaded = false;
  List<Announcement> _myNotifications = <Announcement>[];
  bool _notificationsFirstEmission = true;

  /// Local "seen" stamp: set the moment the Contest tab is opened, so
  /// the badge clears at once instead of waiting for the server-timestamp
  /// write to round-trip through the profile stream.
  DateTime? _seenOverride;

  /// Latest GitHub release (null = no release found yet).
  AppUpdateInfo? _updateInfo;
  bool _updateChecked = false;
  bool _updateDismissed = false;
  bool _updateDownloading = false;

  AppUser? _user;
  AppView _view = AppView.browse;

  /// Active inner tab of the Browse view. Lives in AppState (not in the
  /// Browse screen's local state) so the shell's Submit button can hide
  /// itself off the Local Library tab, and the tab survives swipes.
  BrowseTab _browseTab = BrowseTab.localLibrary;
  BrowseTab get browseTab => _browseTab;

  void setBrowseTab(BrowseTab tab) {
    if (_browseTab == tab) return;
    _browseTab = tab;
    notifyListeners();
  }

  /// Tab the reader was opened from (Browse or the saved Library), so
  /// the reader's back button and the system back button return there
  /// instead of always landing on Browse.
  AppView _readerOrigin = AppView.browse;
  AppView get readerOrigin => _readerOrigin;

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

  /// Current connection health (see [ConnectionStatus]).
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isOffline => _connectionStatus == ConnectionStatus.offline;
  bool get isSlowConnection => _connectionStatus == ConnectionStatus.slow;

  /// Admin-posted news items, newest first.
  List<NewsItem> get adminNews => _adminNews;

  /// True once the admin-news stream has emitted at least once.
  bool get adminNewsResolved => _adminNewsLoaded || !_firebaseReady;

  /// Live headlines from the education/science feeds.
  List<NewsItem> get liveNews => _liveNews;
  bool get liveNewsLoading => _liveNewsLoading;
  bool get liveNewsError => _liveNewsError;

  /// Latest papers from arXiv (Feed "Published papers" tab).
  List<NewsItem> get arxivPapers => _arxivPapers;
  bool get arxivPapersLoading => _arxivPapersLoading;
  bool get arxivPapersError => _arxivPapersError;

  /// Admin announcements (Contest tab), newest first.
  List<Announcement> get announcements => _announcements;
  bool get announcementsResolved => _announcementsLoaded || !_firebaseReady;

  /// The signed-in user's paper-status notices, newest first.
  List<Announcement> get myNotifications => _myNotifications;

  /// General announcements + personal notices merged, newest first.
  /// This is what the Contest tab lists.
  List<Announcement> get allAnnouncements {
    final list = [..._announcements, ..._myNotifications];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Timestamp announcements are "seen" up to: the local override when
  /// the Contest tab was just opened, else the profile's stored stamp.
  DateTime? get _lastSeenAnnouncementAt {
    final stored = _user?.lastSeenAnnouncementAt;
    if (_seenOverride == null) return stored;
    if (stored == null) return _seenOverride;
    return _seenOverride!.isAfter(stored) ? _seenOverride : stored;
  }

  /// Announcements newer than the last-seen stamp. Drives the ping
  /// (badge) on the Contest tab.
  int get unreadAnnouncementCount {
    final seen = _lastSeenAnnouncementAt;
    if (seen == null) return allAnnouncements.length;
    return allAnnouncements.where((a) => a.createdAt.isAfter(seen)).length;
  }

  bool get hasUnreadAnnouncements => unreadAnnouncementCount > 0;

  /// Latest release from GitHub Releases, if one was found.
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// True when a newer version is published and the user hasn't tapped
  /// "Later" this session.
  bool get updateAvailable =>
      !_updateDismissed &&
      _updateInfo != null &&
      _updateInfo!.isNewerThan(AppConstants.currentVersion);

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

  // ------------------------------------------------------------ catalog

  /// E-books list from Open Library (default: education books).
  List<CatalogItem> get ebooks => _ebooks;
  bool get ebooksLoading => _ebooksLoading;
  bool get ebooksError => _ebooksError;
  String get ebooksQuery => _ebooksQuery;

  /// The catalog item whose detail page (or reader) is open.
  CatalogItem? get selectedCatalogItem => _selectedCatalogItem;
  List<CatalogChapter> get catalogChapters => _catalogChapters;
  int get selectedChapterIndex => _selectedChapterIndex;

  CatalogChapter? get selectedChapter {
    if (_catalogChapters.isEmpty) return null;
    final index = _selectedChapterIndex.clamp(0, _catalogChapters.length - 1);
    return _catalogChapters[index];
  }

  bool get catalogTextLoading => _catalogTextLoading;
  bool get catalogTextError => _catalogTextError;
  List<PaperComment> get catalogComments => _catalogComments;
  Set<String> get catalogLikedBy => _catalogLikedBy;
  List<CatalogSave> get catalogSaves => _catalogSaves;
  CatalogProgress? get catalogProgress => _catalogProgress;
  bool isCatalogSaved(String catalogId) =>
      _catalogSaves.any((s) => s.id == catalogId);
  bool get catalogLikedByMe =>
      _user != null && _catalogLikedBy.contains(_user!.id);

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
    // Own pending / rejected papers aren't in the public feed.
    for (final p in _ownPapers) {
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
    _cancelNotificationSub();
    if (accountChanged) _seenOverride = null;
    _userDataRetries = 0;
    // Re-probe admin query access for a new account: a console fix made
    // after a fallback should take effect on next sign-in.
    if (accountChanged) _papersAdminDenied = false;
    // The papers feed depends on isAdmin — re-subscribe if it changed.
    _subscribePapers();
    if (user != null) {
      _subscribeUserData(user);
      _subscribeMyNotifications(user.id);
    } else {
      _bookmarks = <String>{};
      _catalogSaves = <CatalogSave>[];
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
      onError: (Object e, StackTrace s) => _retryUserData(user, 'bookmarks', e),
    );
    _historySub = _repo!.watchHistory(user.id).listen((history) {
      _readingHistory = history;
      _userDataRetries = 0;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _retryUserData(user, 'history', e));
    _catalogSavesSub = _repo!.watchCatalogSaves(user.id).listen(
      (saves) {
        _catalogSaves = saves;
        _userDataRetries = 0;
        notifyListeners();
      },
      onError: (Object e, StackTrace s) =>
          _retryUserData(user, 'catalog saves', e),
    );
  }

  void _retryUserData(AppUser user, String what, Object e) {
    // Signed out or switched accounts while waiting — nothing to retry.
    if (_user?.id != user.id) return;
    debugPrint('[AppState] $what snapshot error, retrying: $e');
    if (_userDataRetries >= _maxUserDataRetries) {
      showToast(
        'Could not load your saved data. Restart the app to try again.',
        Icons.warning,
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
    _catalogSavesSub?.cancel();
    _catalogSavesSub = null;
  }

  /// Signs in with email and password.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  /// The [AppUser] profile arrives asynchronously via [watchAuthUser].
  Future<String?> signIn({required String email, required String password}) {
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
    return _authRepo!.signUp(
      username: username,
      email: email,
      password: password,
    );
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
    _cancelNotificationSub();
    _seenOverride = null;
    _bookmarks = <String>{};
    _catalogSaves = <CatalogSave>[];
    _readingHistory = <ReadEntry>[];
    _subscribePapers();
    navigate(AppView.browse);
    notifyListeners();
    showToast('Signed out', Icons.logout);
  }

  /// Persists the edited profile to Firestore and reflects it locally right
  /// away (the auth stream only re-emits on auth-state changes).
  Future<void> updateUser(AppUser updated) async {
    if (!_firebaseReady) return;
    await _repo!.updateUser(updated);
    _user = updated;
    notifyListeners();
    showToast('Profile updated!', Icons.check_circle);
  }

  /// Persists the current theme on the signed-in user's profile, so
  /// Settings survive sign-out / sign-in (and a new device). Fire-and-
  /// forget: a failed write only logs — the theme still applies on
  /// screen, and the next change retries the save. The local [_user]
  /// copy is updated first so the next sync check sees the saved values
  /// instead of re-applying the old ones.
  Future<void> saveThemeSettings({String? mode, String? accent}) async {
    final user = _user;
    if (!_firebaseReady || user == null) return;
    final newMode = mode ?? user.themeMode;
    final newAccent = accent ?? user.themeAccent;
    _user = user.copyWith(themeMode: newMode, themeAccent: newAccent);
    try {
      await _repo!.saveThemeSettings(user.id, mode: newMode, accent: newAccent);
    } catch (e) {
      debugPrint('[AppState] saveThemeSettings failed: $e');
    }
  }

  // ---------------------------------------------------------------- toasts

  void showToast(String message, [IconData? icon]) {
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
  /// Inner back handler for the visible view: settings detail pages, the
  /// reader's non-first tab, and the submit form's discard confirm all
  /// register here so the phone's system back button unwinds the app's
  /// own navigation first. Cleared on every [navigate]/[openPaper].
  VoidCallback? _innerBackHandler;
  bool get hasInnerBack => _innerBackHandler != null;

  void setInnerBackHandler(VoidCallback? handler) {
    _innerBackHandler = handler;
    notifyListeners();
  }

  /// Runs the registered inner back action, if any. Returns true when a
  /// handler ran (the back press is consumed).
  bool tryInnerBack() {
    final handler = _innerBackHandler;
    if (handler == null) return false;
    handler();
    return true;
  }

  void navigate(AppView v, {void Function()? onAuthPrompt}) {
    if (v == AppView.profile && _user == null) {
      onAuthPrompt?.call();
      return;
    }
    if (v == AppView.admin && _user?.isAdmin != true) return;
    // Admins do admin tasks only — they cannot open the submit-paper form.
    if (v == AppView.post && _user?.isAdmin == true) return;
    _recordReadingTime();
    _innerBackHandler = null;
    _view = v;
    if (v != AppView.reader) _selectedPaperId = null;
    // Leaving the catalog detail/reader closes the open item: its
    // comment/like/progress streams stop and the downloaded text is
    // dropped (re-downloaded on next open).
    if (v != AppView.catalogDetail && v != AppView.catalogReader) {
      _cancelCatalogItemSubs();
      _selectedCatalogItem = null;
      _catalogChapters = <CatalogChapter>[];
      _selectedChapterIndex = 0;
      _catalogTextLoading = false;
      _catalogTextError = false;
    }
    // Opening the Feed refetches the live headlines (the repo caches for
    // 5 minutes, so this is cheap). The Feed screen used to refetch from
    // its own initState, but the tab pages now stay alive between visits,
    // so the trigger moves here — every Feed open, including a re-tap.
    if (v == AppView.feed) {
      unawaited(fetchLiveNews());
      unawaited(fetchArxivPapers());
    }
    // Opening the Contest tab means the user has seen the announcements:
    // clear the ping after a short beat, so a fast swipe-through does
    // not clear it before they could read anything.
    if (v == AppView.polls) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!_disposed && _view == AppView.polls) markAnnouncementsSeen();
      });
    }
    notifyListeners();
  }

  /// Marks every announcement as seen: clears the Contest badge at once
  /// (local override) and stamps the profile so it stays cleared after
  /// a restart. Signed-out users still clear the badge locally; there
  /// is just no profile to stamp.
  void markAnnouncementsSeen() {
    if (unreadAnnouncementCount == 0 && _seenOverride != null) return;
    _seenOverride = DateTime.now();
    notifyListeners();
    final user = _user;
    if (user == null || !_firebaseReady) return;
    unawaited(
      _repo!.markAnnouncementsSeen(user.id).catchError((Object e) {
        debugPrint('[AppState] markAnnouncementsSeen failed: $e');
      }),
    );
  }

  /// Mirrors `openPaper(paper)` — bumps views (fire-and-forget) and starts
  /// the read timer. The live papers stream refreshes the view count.
  void openPaper(Paper paper) {
    if (!_firebaseReady) return;
    _recordReadingTime();
    unawaited(_repo!.incrementViews(paper.id));
    _selectedPaperId = paper.id;
    _readerOrigin = _view;
    _innerBackHandler = null;
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
        unawaited(
          _repo!.addHistoryEntry(
            user.id,
            ReadEntry(
              paperId: paper.id,
              readAt: DateTime.now(),
              secondsSpent: seconds,
            ),
          ),
        );
      }
      _readStart = null;
    }
  }

  // --------------------------------------------------------------- reactions

  /// Toggles the user's like (the heart reaction) on a paper.
  ///
  /// Reads the user's current reaction from the live stream, then
  /// fire-and-forget writes the toggle (pass `null` to remove). A
  /// like is the heart; any older emoji reaction is replaced by it.
  void reactToPaper(String paperId, String emoji) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    final paper = paperById(paperId);
    final current = (paper?.reactions[emoji] ?? const []).contains(user.id);
    final toSet = current ? null : emoji;
    unawaited(_repo!.setReaction(paperId, user.id, toSet));
    if (!current) showToast('Liked', Icons.favorite);
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
    showToast('Comment posted', Icons.chat_bubble);
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
      showToast('Paper saved!', Icons.bookmark);
    } else {
      showToast('Removed from saved', Icons.bookmark_remove);
    }
  }

  // --------------------------------------------------------------- catalog

  /// Fetches the e-books list from Open Library. [search] is free text;
  /// empty means the default education list. Same shape as
  /// [fetchLiveNews]: the repo caches for 5 minutes, the loading flag
  /// only shows while the list is empty. Never throws.
  Future<void> fetchEbooks({String? search, bool forceRefresh = false}) async {
    if (_ebooksLoading) return;
    _ebooksLoading = true;
    _ebooksError = false;
    notifyListeners();
    try {
      final items = await _catalogRepo.fetchEbooks(
        search: search,
        forceRefresh: forceRefresh,
      );
      _ebooks = items ?? <CatalogItem>[];
      _ebooksQuery = (search == null || search.trim().isEmpty)
          ? ''
          : search.trim();
      // Null means the fetch failed (not an empty search result).
      _ebooksError = items == null;
    } catch (e) {
      debugPrint('[AppState] e-books fetch failed: $e');
      _ebooksError = true;
    }
    _ebooksLoading = false;
    notifyListeners();
  }

  /// Opens a catalog item's detail page and subscribes to its comments,
  /// likes and (when signed in) reading progress.
  void openCatalogItem(CatalogItem item) {
    _cancelCatalogItemSubs();
    _selectedCatalogItem = item;
    _catalogChapters = <CatalogChapter>[];
    _selectedChapterIndex = 0;
    _catalogTextLoading = false;
    _catalogTextError = false;
    _catalogComments = <PaperComment>[];
    _catalogLikedBy = <String>{};
    _catalogProgress = null;
    _subscribeCatalogItem(item.id);
    navigate(AppView.catalogDetail);
    // Start the chapter download now so the chapter list is ready on
    // the detail screen (the reader reuses it on first chapter open).
    unawaited(_ensureCatalogText());
  }

  void _subscribeCatalogItem(String catalogId) {
    if (!_firebaseReady) return;
    _catalogCommentsSub = _repo!.watchCatalogComments(catalogId).listen(
      (comments) {
        _catalogComments = comments;
        notifyListeners();
      },
      onError: (Object e, StackTrace s) =>
          debugPrint('[AppState] catalog comments error: $e'),
    );
    _catalogReactionsSub = _repo!.watchCatalogReactions(catalogId).listen(
      (likedBy) {
        _catalogLikedBy = likedBy;
        notifyListeners();
      },
      onError: (Object e, StackTrace s) =>
          debugPrint('[AppState] catalog reactions error: $e'),
    );
    final user = _user;
    if (user != null) {
      _catalogProgressSub = _repo!
          .watchCatalogProgress(user.id, catalogId)
          .listen(
            (progress) {
              _catalogProgress = progress;
              notifyListeners();
            },
            onError: (Object e, StackTrace s) =>
                debugPrint('[AppState] catalog progress error: $e'),
          );
    }
  }

  void _cancelCatalogItemSubs() {
    _catalogCommentsSub?.cancel();
    _catalogCommentsSub = null;
    _catalogReactionsSub?.cancel();
    _catalogReactionsSub = null;
    _catalogProgressSub?.cancel();
    _catalogProgressSub = null;
  }

  /// Downloads the open book's full text (once) and splits it into
  /// chapters. Returns false when the download fails. The detail screen
  /// calls this on open so the chapter list is ready; the reader calls
  /// it too when opening a chapter directly. If the user opened another
  /// book while this download was in flight, the result is dropped.
  Future<bool> _ensureCatalogText() async {
    final item = _selectedCatalogItem;
    if (item == null) return false;
    if (_catalogChapters.isNotEmpty) return true;
    if (_catalogTextLoading) return false;
    _catalogTextLoading = true;
    _catalogTextError = false;
    notifyListeners();
    final text = await _catalogRepo.fetchFullText(item);
    if (_selectedCatalogItem?.id != item.id) return false;
    if (text == null || text.trim().isEmpty) {
      _catalogTextLoading = false;
      _catalogTextError = true;
      notifyListeners();
      return false;
    }
    _catalogChapters = splitChapters(text);
    _catalogTextLoading = false;
    notifyListeners();
    return true;
  }

  /// Retries the chapter download from the detail screen's error state.
  Future<void> reloadCatalogChapters() async {
    await _ensureCatalogText();
  }

  /// Opens a chapter in the text reader. Downloads the book's full text
  /// on first open (split into chapters afterwards) and marks the
  /// chapter read. While downloading, the detail screen shows its
  /// loading state; a failed download shows its error state instead.
  Future<void> openCatalogChapter(int index) async {
    final item = _selectedCatalogItem;
    if (item == null) return;
    if (!await _ensureCatalogText()) return;
    if (index < 0 || index >= _catalogChapters.length) return;
    _selectedChapterIndex = index;
    navigate(AppView.catalogReader);
    _markCatalogChapterRead(item.id, index);
  }

  /// Toggles the user's save (bookmark) on a catalog item.
  void toggleCatalogSave(CatalogItem item) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    final saved = !isCatalogSaved(item.id);
    unawaited(_repo!.setCatalogSave(user.id, item, saved));
    if (saved) {
      showToast('Book saved!', Icons.bookmark);
    } else {
      showToast('Removed from saved', Icons.bookmark_remove);
    }
  }

  /// Toggles the user's like (heart) on a catalog item.
  void reactToCatalogItem(String catalogId) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    final current = _catalogLikedBy.contains(user.id);
    unawaited(
      _repo!.setCatalogReaction(catalogId, user.id, current ? null : '❤️'),
    );
    if (!current) showToast('Liked', Icons.favorite);
  }

  void addCatalogComment(String catalogId, String text) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null || text.trim().isEmpty) return;
    final comment = PaperComment(
      id: '',
      userId: user.id,
      username: user.username,
      avatar: user.avatar,
      text: text.trim(),
      createdAt: DateTime.now(),
      likes: 0,
      likedBy: const [],
    );
    unawaited(_repo!.addCatalogComment(catalogId, comment));
    showToast('Comment posted', Icons.chat_bubble);
  }

  void toggleCatalogCommentLike(String catalogId, String commentId) {
    if (!_firebaseReady) return;
    final user = _user;
    if (user == null) return;
    unawaited(_repo!.toggleCatalogCommentLike(catalogId, commentId, user.id));
  }

  /// Marks a chapter read and remembers it as the last-read chapter.
  void _markCatalogChapterRead(String catalogId, int index) {
    final user = _user;
    if (user == null || !_firebaseReady) return;
    final read = {...?_catalogProgress?.readChapterIndices, index}.toList()
      ..sort();
    final progress = CatalogProgress(
      lastChapterIndex: index,
      lastCharOffset: 0,
      readChapterIndices: read,
      updatedAt: DateTime.now(),
    );
    _catalogProgress = progress;
    unawaited(_repo!.saveCatalogProgress(user.id, catalogId, progress));
  }

  /// Saves the reader's position inside a chapter (scroll fraction ->
  /// char offset). Fire-and-forget; the progress stream echoes it back.
  void saveCatalogChapterPosition(
    String catalogId,
    int chapterIndex,
    int charOffset,
  ) {
    final user = _user;
    if (user == null || !_firebaseReady) return;
    final read = {
      ...?_catalogProgress?.readChapterIndices,
      chapterIndex,
    }.toList()..sort();
    final progress = CatalogProgress(
      lastChapterIndex: chapterIndex,
      lastCharOffset: charOffset,
      readChapterIndices: read,
      updatedAt: DateTime.now(),
    );
    _catalogProgress = progress;
    unawaited(_repo!.saveCatalogProgress(user.id, catalogId, progress));
  }

  // -------------------------------------------------------------------- news

  /// Fetches live education/science headlines. Called every time the
  /// Feed tab opens and on pull-to-refresh. The repo caches results for
  /// 5 minutes, so a revisit inside that window reuses the cached list
  /// and a stale one is refetched — headlines no longer freeze after
  /// the first load. The loading spinner only shows while the list is
  /// empty (see feed_screen.dart), so a background refresh never
  /// flashes over headlines already on screen. Never throws.
  Future<void> fetchLiveNews({bool forceRefresh = false}) async {
    if (_liveNewsLoading) return;
    _liveNewsLoading = true;
    _liveNewsError = false;
    notifyListeners();
    try {
      final items = await _newsRepo.fetchLiveNews(forceRefresh: forceRefresh);
      _liveNews = items;
      _liveNewsError = items.isEmpty;
    } catch (e) {
      debugPrint('[AppState] live news fetch failed: $e');
      _liveNewsError = true;
    }
    _liveNewsLoading = false;
    notifyListeners();
  }

  /// Fetches the latest arXiv papers for the Feed's "Published papers"
  /// tab. Same shape as [fetchLiveNews]: the repo caches for 5 minutes,
  /// the loading state only shows while the list is empty, and a
  /// background refresh never flashes over papers already on screen.
  /// Never throws.
  Future<void> fetchArxivPapers({bool forceRefresh = false}) async {
    if (_arxivPapersLoading) return;
    _arxivPapersLoading = true;
    _arxivPapersError = false;
    notifyListeners();
    try {
      final items = await _newsRepo.fetchArxivPapers(
        forceRefresh: forceRefresh,
      );
      _arxivPapers = items;
      _arxivPapersError = items.isEmpty;
    } catch (e) {
      debugPrint('[AppState] arXiv papers fetch failed: $e');
      _arxivPapersError = true;
    }
    _arxivPapersLoading = false;
    notifyListeners();
  }

  /// Deletes an admin-posted news item. Returns false — and toasts —
  /// when the write is rejected.
  Future<bool> deleteNews(String newsId) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.deleteNews(newsId);
      showToast('News removed', Icons.delete);
      return true;
    } catch (e) {
      debugPrint('deleteNews failed: $e');
      showToast('Could not remove the news.', Icons.warning);
      return false;
    }
  }

  // ---------------------------------------------------------- announcements

  /// Posts a general announcement to the Contest tab (admin only).
  /// Returns true when Firestore accepted the write.
  Future<bool> postAnnouncement({
    required String title,
    required String body,
  }) async {
    if (!_firebaseReady) return false;
    final user = _user;
    if (user == null || !user.isAdmin) return false;
    if (title.trim().isEmpty) return false;
    try {
      await _repo!.postAnnouncement(
        title: title.trim(),
        body: body.trim(),
        createdBy: user.id,
      );
      showToast('Announcement posted!', Icons.campaign);
      return true;
    } catch (e) {
      debugPrint('postAnnouncement failed: $e');
      showToast('Could not post the announcement.', Icons.warning);
      return false;
    }
  }

  /// Deletes a general announcement (admin only).
  Future<bool> deleteAnnouncement(String announcementId) async {
    if (!_firebaseReady) return false;
    try {
      await _repo!.deleteAnnouncement(announcementId);
      showToast('Announcement removed', Icons.delete);
      return true;
    } catch (e) {
      debugPrint('deleteAnnouncement failed: $e');
      showToast('Could not remove the announcement.', Icons.warning);
      return false;
    }
  }

  // -------------------------------------------------------------- app update

  /// Checks GitHub Releases once for a newer version. No Firebase
  /// needed, so it also runs signed out. Silent when there is no
  /// release yet, no APK is attached, or the request fails — then no
  /// prompt is shown. With [forceRefresh] (Settings > Check for
  /// updates) it checks again even if it already checked this session,
  /// and clears a "Later" dismissal so the prompt can show again.
  Future<void> checkForUpdate({bool forceRefresh = false}) async {
    if (_updateChecked && !forceRefresh) return;
    _updateChecked = true;
    if (forceRefresh) _updateDismissed = false;
    _updateInfo = await fetchLatestGithubRelease();
    if (updateAvailable) notifyListeners();
  }

  /// Latest release, for the Settings > What's New page. Reuses the
  /// startup check when it already ran; otherwise fetches once.
  Future<AppUpdateInfo?> fetchLatestRelease() async {
    if (_updateInfo != null) return _updateInfo;
    _updateInfo = await fetchLatestGithubRelease();
    return _updateInfo;
  }

  /// True when the signed-in user has never seen (or skipped) the
  /// first-time help tour. The tour shows once per account.
  bool get shouldShowOnboarding => _user != null && !_user!.hasSeenOnboarding;

  /// Marks the help tour as seen, on the profile and locally, so it
  /// never shows again for this account. Fire-and-forget: a failed
  /// write only logs — the local flag still stops the tour this
  /// session, and the next sign-in retries the save by showing it
  /// again only if the profile still says unseen.
  Future<void> markOnboardingSeen() async {
    final user = _user;
    if (user == null || user.hasSeenOnboarding) return;
    _user = user.copyWith(hasSeenOnboarding: true);
    notifyListeners();
    try {
      await _repo!.saveOnboardingSeen(user.id);
    } catch (e) {
      debugPrint('[AppState] markOnboardingSeen failed: $e');
    }
  }

  /// Hides the update prompt for the rest of this session ("Later").
  /// It shows again on the next app open while a newer version exists.
  void dismissUpdate() {
    _updateDismissed = true;
    notifyListeners();
  }

  /// Starts the in-app update download for the published version.
  /// Returns true when the download started (or the link was opened on
  /// web) — the caller should dismiss the prompt then. Returns false when
  /// nothing started, so the caller keeps the dialog open for a retry.
  /// Android: the APK downloads via DownloadManager with progress in the
  /// notification shade, then the system installer opens. Web: falls back
  /// to opening the download link in the browser.
  Future<bool> startUpdateDownload() async {
    final info = _updateInfo;
    if (info == null || info.downloadUrl.isEmpty) return false;
    if (kIsWeb) {
      final url = Uri.tryParse(info.downloadUrl);
      if (url == null) return false;
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    if (_updateDownloading) {
      showToast(
        'Update is already downloading — check the notification.',
        Icons.download,
      );
      return true;
    }
    _updateDownloading = true;
    final result = await AppUpdater.downloadAndInstall(
      url: info.downloadUrl,
      version: info.latestVersion,
    );
    _updateDownloading = false;
    switch (result) {
      case 'started':
        showToast(
          'Downloading update — watch the notification.',
          Icons.download,
        );
        return true;
      case 'already_downloading':
        showToast(
          'Update is already downloading — check the notification.',
          Icons.download,
        );
        return true;
      case 'needs_unknown_sources':
        showToast(
          'Allow Arxiv to install apps in Settings, then tap Update again.',
          Icons.warning,
        );
        return false;
      default:
        showToast(
          'Could not start the download. Check your connection and try again.',
          Icons.warning,
        );
        return false;
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
    showToast('Paper submitted for review!', Icons.send);
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
      showToast('Could not attach the PDF.', Icons.warning);
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
        Icons.warning,
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
      showToast('PDF upload failed. Try again.', Icons.warning);
      return null;
    }
  }

  // ------------------------------------------------------------------- admin

  /// Sends the author a private paper-status notice. Best-effort: a
  /// failed notice never fails the status change itself, and the notice
  /// is only written after the status write succeeded.
  Future<void> _notifyPaperStatus(
    Paper paper,
    PaperStatus status, {
    String? reason,
  }) async {
    final adminId = _user?.id ?? '';
    final title = switch (status) {
      PaperStatus.approved => 'Your paper was approved',
      PaperStatus.rejected => 'Your paper was not approved',
      PaperStatus.revision => 'Revision requested for your paper',
      _ => 'Update on your paper',
    };
    var body = '“${paper.title}”';
    if (reason != null && reason.trim().isNotEmpty) {
      body += ' — ${reason.trim()}';
    } else if (status == PaperStatus.approved) {
      body += ' is now published in the Local Library.';
    }
    try {
      await _repo!.createNotification(
        uid: paper.authorId,
        title: title,
        body: body,
        paperId: paper.id,
        paperTitle: paper.title,
        paperStatus: status.name,
        createdBy: adminId,
      );
    } catch (e) {
      debugPrint('[AppState] paper-status notice failed: $e');
    }
  }

  /// Approves a paper. Returns true when Firestore accepted the write;
  /// surfaces a toast either way so a rejected write (e.g. unpublished
  /// rules) can never look like a success.
  Future<bool> approvePaper(String paperId) async {
    if (!_firebaseReady) return false;
    final paper = paperById(paperId);
    try {
      await _repo!.updatePaperStatus(paperId, PaperStatus.approved);
      showToast('Paper approved and published!', Icons.check_circle);
      if (paper != null) {
        unawaited(_notifyPaperStatus(paper, PaperStatus.approved));
      }
      return true;
    } catch (e) {
      debugPrint('approvePaper failed: $e');
      showToast('Could not approve the paper.', Icons.warning);
      return false;
    }
  }

  Future<bool> rejectPaper(String paperId, String reason) async {
    if (!_firebaseReady) return false;
    final paper = paperById(paperId);
    try {
      await _repo!.updatePaperStatus(
        paperId,
        PaperStatus.rejected,
        reason: reason,
      );
      showToast('Paper rejected.', Icons.cancel);
      if (paper != null) {
        unawaited(
          _notifyPaperStatus(paper, PaperStatus.rejected, reason: reason),
        );
      }
      return true;
    } catch (e) {
      debugPrint('rejectPaper failed: $e');
      showToast('Could not reject the paper.', Icons.warning);
      return false;
    }
  }

  Future<bool> requestRevision(String paperId, String reason) async {
    if (!_firebaseReady) return false;
    final paper = paperById(paperId);
    try {
      await _repo!.updatePaperStatus(
        paperId,
        PaperStatus.revision,
        reason: reason,
      );
      showToast('Revision request sent.');
      if (paper != null) {
        unawaited(
          _notifyPaperStatus(paper, PaperStatus.revision, reason: reason),
        );
      }
      return true;
    } catch (e) {
      debugPrint('requestRevision failed: $e');
      showToast('Could not send the revision request.', Icons.warning);
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
      showToast('Could not archive the paper.', Icons.warning);
      return false;
    }
  }

  /// Deletes the paper document and its comments/reactions subcollections.
  /// Other users' bookmark documents pointing at this paper are left orphaned
  /// (acceptable — bookmarks stream only id lists and UI guards missing papers).
  Future<bool> deletePaper(String paperId) async {
    if (!_firebaseReady) return false;
    final user = _user;
    if (user == null) return false;
    try {
      await _repo!.deletePaper(
        paperId,
        deleterUid: user.id,
        deleterIsAdmin: user.isAdmin,
      );
      showToast('Paper deleted', Icons.delete);
      return true;
    } catch (e) {
      debugPrint('deletePaper failed: $e');
      showToast('Could not delete the paper.', Icons.warning);
      return false;
    }
  }

  /// Deletes a user profile (admin only per `firestore.rules`) and bans
  /// the account from signing back in (see FirestoreRepository.deleteUser
  /// — a profile delete alone would let them sign straight back in).
  /// The user's papers are kept. Self-delete is refused here as well as
  /// in the admin UI, and a non-admin can never reach the write.
  /// Returns false — and toasts — when the write is rejected.
  Future<bool> deleteUser(String uid) async {
    if (!_firebaseReady) return false;
    final user = _user;
    if (user == null || !user.isAdmin) return false;
    if (uid == user.id) {
      showToast('You cannot delete your own account.', Icons.warning);
      return false;
    }
    try {
      await _repo!.deleteUser(
        uid,
        deleterUid: user.id,
        deleterIsAdmin: user.isAdmin,
      );
      showToast('User deleted — they can no longer sign in.', Icons.delete);
      return true;
    } catch (e) {
      debugPrint('deleteUser failed: $e');
      showToast('Could not delete the user.', Icons.warning);
      return false;
    }
  }

  // -------------------------------------------------------------- lifecycle

  @override
  void dispose() {
    _disposed = true;
    _papersSub?.cancel();
    _ownSub?.cancel();
    unawaited(_ownDispose?.call());
    _usersSub?.cancel();
    _authSub?.cancel();
    _newsSub?.cancel();
    _announcementsSub?.cancel();
    _notificationsSub?.cancel();
    _slowTimer?.cancel();
    _cancelUserSubs();
    _cancelCatalogItemSubs();
    _repo?.dispose();
    super.dispose();
  }
}
