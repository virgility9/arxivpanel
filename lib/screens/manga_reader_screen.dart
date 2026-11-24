/// In-app page reader for one manga chapter, with Tachiyomi-style
/// customization (per series, stored in Firestore): reading mode
/// (paged LTR/RTL/vertical, long strip), scale type, background,
/// tap zones, rotation lock, fullscreen, custom brightness and colour
/// filters. Settings live in [AppState.mangaReaderSettings] and open
/// in a bottom sheet from the gear button (or a long press on a page).
/// The system back button returns to the detail screen, same as the
/// back arrow. Page progress is not saved yet (a later update can
/// add it).
library;

import 'dart:async';

import 'package:flutter/material.dart';
// ScrollCacheExtent is NOT in material.dart — it lives in rendering,
// so this import is required to name it (the analyzer's Quick Fix
// offers exactly this line).
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../models/reader_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';
import 'manga_reader_settings_sheet.dart';

class MangaReaderScreen extends StatefulWidget {
  const MangaReaderScreen({
    super.key,
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late final PageController _pages;
  final ScrollController _strip = ScrollController();
  final TransformationController _zoom = TransformationController();
  int _pageIndex = 0;
  bool _menusVisible = true;
  bool _zoomed = false;
  bool _wasPaged = true;

  /// The chapter this State instance is showing. The shell keys the
  /// screen by chapter index, so a chapter change remounts the screen
  /// and the page index resets to the chapter's last-read page (or
  /// the first page when opening fresh).
  late final int _chapterIndex;

  /// Page count of this chapter, captured at open. (The app-wide page
  /// URLs move on to the next chapter before dispose runs, so the
  /// last-read save uses this copy.)
  late final int _pageCount;

  ReaderRotation? _appliedRotation;
  bool? _appliedFullscreen;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.appState.selectedMangaChapterIndex;
    _pageCount = widget.appState.mangaPageUrls.length;
    // Resume at the last-read page (0 when opening fresh — the
    // detail screen passes the saved page as the start page).
    _pageIndex = _pageCount == 0
        ? 0
        : widget.appState.mangaStartPage.clamp(0, _pageCount - 1).toInt();
    _pages = PageController(initialPage: _pageIndex);
    widget.appState.setInnerBackHandler(_backToDetail);
    final s = widget.appState.mangaReaderSettings;
    _menusVisible = !s.fullscreen;
    _wasPaged = s.isPaged;
    _zoom.addListener(_onZoomChanged);
    _strip.addListener(_onStripScroll);
    _applySystemSettings(s);
    // Long strip: jump to the resumed page after the first frame
    // (the strip's scroll extent is only known once laid out).
    // Paged mode needs no jump — the PageController starts there.
    if (_pageIndex > 0 && !s.isPaged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToPage(_pageIndex, s);
      });
    }
  }

  @override
  void dispose() {
    _savePagePosition();
    _zoom.removeListener(_onZoomChanged);
    _strip.removeListener(_onStripScroll);
    widget.appState.setInnerBackHandler(null);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pages.dispose();
    _strip.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _backToDetail() {
    _savePagePosition();
    widget.appState.navigate(AppView.catalogDetail);
  }

  /// Saves the last-read page for this chapter (fire-and-forget).
  /// Called when the reader closes or the chapter changes — the shell
  /// remounts this screen per chapter, so dispose runs on every
  /// chapter switch too. Uses this screen's own chapter index and
  /// page count: by the time dispose runs, the app-wide chapter
  /// index and page URLs have already moved on to the next chapter.
  void _savePagePosition() {
    final appState = widget.appState;
    final item = appState.selectedCatalogItem;
    final chapters = appState.mangaChapters;
    if (item == null || _chapterIndex >= chapters.length) return;
    if (_pageCount == 0) return;
    appState.saveMangaPagePosition(
      item.id,
      chapters[_chapterIndex].id,
      _pageIndex.clamp(0, _pageCount - 1).toInt(),
      _pageCount,
    );
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
    }
  }

  /// Long strip: the page number is a scroll-fraction estimate (pages
  /// have different heights, so there is no exact offset per page).
  /// When the estimate moves to a new page, the NEXT page starts
  /// loading in the background, so it is ready when it scrolls in.
  void _onStripScroll() {
    if (!mounted || !_strip.hasClients) return;
    final count = widget.appState.mangaPageUrls.length;
    if (count <= 1) return;
    final max = _strip.position.maxScrollExtent;
    if (max <= 0) return;
    final index = ((_strip.offset / max) * (count - 1)).round().clamp(
      0,
      count - 1,
    ).toInt();
    if (index != _pageIndex) {
      setState(() => _pageIndex = index);
      _precachePage(index + 1);
    }
  }

  /// Starts loading one strip page before it scrolls in, decoded at
  /// the same 1x screen size the reader uses — the cache entry must
  /// match what NetImage will ask for, or the precache is wasted and
  /// the page decodes twice. Failures are ignored: the page's own
  /// NetImage shows its placeholder and retries on rebuild.
  void _precachePage(int index) {
    final urls = widget.appState.mangaPageUrls;
    if (!mounted || index < 0 || index >= urls.length) return;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * dpr).round();
    unawaited(
      precacheImage(
        ResizeImage(NetworkImage(urls[index]), width: cacheWidth),
        context,
      ).catchError((_) {}),
    );
  }

  /// Applies the rotation lock and fullscreen system UI for the
  /// current settings, but only when they changed (SystemChrome calls
  /// on every build would fight the platform).
  void _applySystemSettings(MangaReaderSettings s) {
    if (s.rotation != _appliedRotation) {
      _appliedRotation = s.rotation;
      SystemChrome.setPreferredOrientations(_orientationsFor(s.rotation));
    }
    final immersive = s.fullscreen && !_menusVisible;
    if (immersive != _appliedFullscreen) {
      _appliedFullscreen = immersive;
      SystemChrome.setEnabledSystemUIMode(
        immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  }

  List<DeviceOrientation> _orientationsFor(ReaderRotation r) => switch (r) {
    ReaderRotation.def || ReaderRotation.free => DeviceOrientation.values,
    ReaderRotation.portrait => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    ReaderRotation.landscape => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    ReaderRotation.lockedPortrait => const [DeviceOrientation.portraitUp],
    ReaderRotation.lockedLandscape => const [DeviceOrientation.landscapeLeft],
    ReaderRotation.reversePortrait => const [DeviceOrientation.portraitDown],
  };

  void _openSettings() {
    showMangaReaderSettingsSheet(
      context: context,
      appState: widget.appState,
      theme: widget.theme,
    );
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
  }

  void _goToPage(int index, MangaReaderSettings s) {
    final pageCount = widget.appState.mangaPageUrls.length;
    if (pageCount == 0) return;
    final target = index.clamp(0, pageCount - 1).toInt();
    setState(() => _pageIndex = target);
    if (s.isPaged) {
      if (!_pages.hasClients) return;
      if (s.animateTransitions) {
        _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _pages.jumpToPage(target);
      }
    } else {
      if (!_strip.hasClients) return;
      final max = _strip.position.maxScrollExtent;
      final offset = pageCount <= 1 || max <= 0
          ? 0.0
          : (target / (pageCount - 1)) * max;
      if (s.animateTransitions) {
        _strip.animateTo(
          offset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _strip.jumpTo(offset);
      }
    }
  }

  void _nextPage(int pageCount) {
    if (_pageIndex + 1 >= pageCount) return;
    _goToPage(_pageIndex + 1, widget.appState.mangaReaderSettings);
  }

  void _prevPage() {
    if (_pageIndex <= 0) return;
    _goToPage(_pageIndex - 1, widget.appState.mangaReaderSettings);
  }

  /// Tap zones: left/right (or top/bottom for vertical paging) turn
  /// pages, the centre toggles the menus. RTL reading mirrors the
  /// sides; the invert setting mirrors them again. While zoomed, taps
  /// only toggle the menus — they never turn a page. Long strip is
  /// different: there are no pages to turn, the reader scrolls, so
  /// EVERY tap only toggles the menus. Turning on a tap would scroll
  /// the strip to a guessed offset (pages have unequal heights) and
  /// land mid-panel on a cut face or a half-clipped bubble.
  void _onTap(TapUpDetails details, MangaReaderSettings s, int pageCount) {
    if (_zoomed) {
      setState(() => _menusVisible = !_menusVisible);
      return;
    }
    if (!s.isPaged) {
      setState(() => _menusVisible = !_menusVisible);
      return;
    }
    if (s.tapZones == TapZones.disabled) {
      setState(() => _menusVisible = !_menusVisible);
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final dx = details.globalPosition.dx / size.width;
    final dy = details.globalPosition.dy / size.height;
    final flipH =
        s.invertTapZones == InvertTapZones.horizontal ||
        s.invertTapZones == InvertTapZones.both;
    final flipV =
        s.invertTapZones == InvertTapZones.vertical ||
        s.invertTapZones == InvertTapZones.both;
    if (s.isVerticalPaging) {
      // Top = previous, bottom = next (thirds); centre toggles menus.
      if (dy < 1 / 3) {
        flipV ? _nextPage(pageCount) : _prevPage();
      } else if (dy > 2 / 3) {
        flipV ? _prevPage() : _nextPage(pageCount);
      } else {
        setState(() => _menusVisible = !_menusVisible);
      }
      return;
    }
    // Left is "next" when reading right to left; the invert setting
    // flips that again.
    final leftIsNext = s.isRtl != flipH;
    if (s.tapZones == TapZones.rightAndLeft) {
      if (dx < 0.5) {
        leftIsNext ? _nextPage(pageCount) : _prevPage();
      } else {
        leftIsNext ? _prevPage() : _nextPage(pageCount);
      }
      return;
    }
    // Default: edge thirds turn pages, centre toggles the menus.
    if (dx < 1 / 3) {
      leftIsNext ? _nextPage(pageCount) : _prevPage();
    } else if (dx > 2 / 3) {
      leftIsNext ? _prevPage() : _nextPage(pageCount);
    } else {
      setState(() => _menusVisible = !_menusVisible);
    }
  }

  /// Grayscale / invert / tint, nested — one ColorFiltered each, so
  /// any combination works.
  Widget _applyFilters(Widget child, MangaReaderSettings s) {
    var out = child;
    if (s.tint != PageTint.none) {
      out = ColorFiltered(
        colorFilter: ColorFilter.matrix(_tintMatrix(s.tint)),
        child: out,
      );
    }
    if (s.inverted) {
      out = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: out,
      );
    }
    if (s.grayscale) {
      out = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: out,
      );
    }
    return out;
  }

  List<double> _tintMatrix(PageTint tint) => switch (tint) {
    PageTint.none => const <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    PageTint.sepia => const <double>[
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0, 0, 0, 1, 0,
    ],
    PageTint.warm => const <double>[
      1.08, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 0.92, 0, 0,
      0, 0, 0, 1, 0,
    ],
    PageTint.cool => const <double>[
      0.92, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 1.08, 0, 0,
      0, 0, 0, 1, 0,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        final s = appState.mangaReaderSettings;
        final item = appState.selectedCatalogItem;
        final chapter = appState.selectedMangaChapter;
        final pageUrls = appState.mangaPageUrls;
        final loading = appState.mangaPagesLoading;
        _applySystemSettings(s);
        // The reader switched between paged and long strip: land on
        // the current page in the new mode (after this frame, once
        // the new controller has clients).
        if (s.isPaged != _wasPaged) {
          _wasPaged = s.isPaged;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _goToPage(_pageIndex, s);
          });
        }
        final bgColor = switch (s.background) {
          ReaderBackground.black => Colors.black,
          ReaderBackground.gray => const Color(0xFF2A2A2A),
          ReaderBackground.white => Colors.white,
          ReaderBackground.auto => p.c.surface,
        };
        final onBg = s.background == ReaderBackground.white
            ? Colors.black87
            : s.background == ReaderBackground.auto
                ? p.c.text
                : Colors.white;
        final faintOnBg = onBg.withAlpha(150);
        if (item == null || chapter == null || pageUrls.isEmpty) {
          return Container(
            color: bgColor,
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                child: EmptyState(
                  palette: p,
                  icon: Icons.image,
                  title: loading ? 'Loading pages…' : 'No pages to show',
                  sub: loading
                      ? 'Fetching this chapter from MangaDex.'
                      : 'Try another chapter.',
                ),
              ),
            ),
          );
        }
        final chapterCount = appState.mangaChapters.length;
        return Container(
          color: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_menusVisible) _topBar(p, s, item, chapter, pageUrls.length,
                  onBg, faintOnBg, isNarrow),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTap(d, s, pageUrls.length),
                  onLongPress: () {
                    if (s.showActionsOnLongTap) _openSettings();
                  },
                  child: Stack(
                    children: [
                      _applyFilters(_pagesArea(s, pageUrls), s),
                      if (s.dimOpacity > 0)
                        IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(
                              alpha: s.dimOpacity,
                            ),
                          ),
                        ),
                      if (_zoomed)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Material(
                            color: p.c.surface,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Reset zoom',
                              icon: Icon(Icons.zoom_out_map, color: p.c.text),
                              onPressed: _resetZoom,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_menusVisible)
                _footer(p, s, chapterCount, pageUrls.length, loading,
                    onBg, faintOnBg, isNarrow),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(
    AppPalette p,
    MangaReaderSettings s,
    CatalogItem item,
    MangaChapter chapter,
    int pageCount,
    Color onBg,
    Color faintOnBg,
    bool isNarrow,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: faintOnBg.withAlpha(60))),
      ),
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 8 : 16,
        isNarrow ? 8 : 12,
        isNarrow ? 8 : 16,
        isNarrow ? 8 : 12,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to ${item.title}',
            icon: Icon(Icons.arrow_back, color: onBg, size: 22),
            onPressed: _backToDetail,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.label,
                  style: displayStyle(p, size: 16, weight: FontWeight.w700)
                      .copyWith(color: onBg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.title,
                  style: monoStyle(p, size: 10, color: faintOnBg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (s.showPageNumber)
            Text(
              'Page ${_pageIndex + 1} of $pageCount',
              style: monoStyle(p, size: 10, color: faintOnBg),
            ),
          IconButton(
            tooltip: 'Reader settings',
            icon: Icon(Icons.settings, color: onBg, size: 22),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  /// Paged modes: a PageView (LTR, RTL via reverse, or vertical).
  /// Long strip: a ListView of full-width pages. Pinch zoom is paged
  /// only — in long strip the list itself scrolls.
  Widget _pagesArea(MangaReaderSettings s, List<String> pageUrls) {
    if (s.isPaged) {
      return PageView.builder(
        controller: _pages,
        reverse: s.isRtl,
        scrollDirection:
            s.isVerticalPaging ? Axis.vertical : Axis.horizontal,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: pageUrls.length,
        onPageChanged: (i) {
          setState(() => _pageIndex = i);
          _resetZoom();
        },
        itemBuilder: (context, i) {
          return InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 4,
            panEnabled: _zoomed,
            child: Center(
              child: NetImage(url: pageUrls[i], fit: s.fit, cacheScale: 1.0),
            ),
          );
        },
      );
    }
    return ListView.builder(
      controller: _strip,
      // A full viewport of look-ahead (the default 250px is a sliver
      // of one tall manhwa page): the next page's widget builds — and
      // its image starts loading — a screen before it appears.
      // (scrollCacheExtent: the plain `cacheExtent` double was
      // deprecated after Flutter v3.41.0-0.0.pre.)
      scrollCacheExtent:
          ScrollCacheExtent.pixels(MediaQuery.sizeOf(context).height),
      itemCount: pageUrls.length,
      itemBuilder: (context, i) {
        // Long strip is fit-width by nature: width only, the height
        // follows the page's own aspect ratio. Decoded at exactly
        // screen size (1.0, not the 2x covers use): a tall page at 2x
        // is ~240MB in RAM and thrashes the image cache, so pages
        // loaded slowly and re-decoded on every scroll.
        final image = NetImage(
          url: pageUrls[i],
          width: double.infinity,
          fit: BoxFit.fitWidth,
          cacheScale: 1.0,
        );
        if (s.hasStripGaps && i < pageUrls.length - 1) {
          return Column(
            children: [image, const SizedBox(height: 12)],
          );
        }
        return image;
      },
    );
  }

  /// Footer: previous chapter, page slider, next chapter — the
  /// Tachiyomi reader bar. The slider jumps pages in paged modes and
  /// scrolls in long strip.
  Widget _footer(
    AppPalette p,
    MangaReaderSettings s,
    int chapterCount,
    int pageCount,
    bool loading,
    Color onBg,
    Color faintOnBg,
    bool isNarrow,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: faintOnBg.withAlpha(60))),
      ),
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 8 : 16,
        8,
        isNarrow ? 8 : 16,
        isNarrow ? 8 : 16,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous chapter',
            icon: Icon(Icons.chevron_left, color: onBg, size: 26),
            onPressed: _chapterIndex > 0 && !loading
                ? () => widget.appState.openMangaChapter(_chapterIndex - 1)
                : null,
          ),
          if (pageCount > 1)
            Expanded(
              child: Slider(
                value: _pageIndex.clamp(0, pageCount - 1).toDouble(),
                min: 0,
                max: (pageCount - 1).toDouble(),
                divisions: pageCount - 1,
                activeColor: p.accent.accent,
                inactiveColor: faintOnBg.withAlpha(80),
                onChanged: (v) => _goToPage(v.round(), s),
              ),
            )
          else
            const Spacer(),
          IconButton(
            tooltip: 'Next chapter',
            icon: Icon(Icons.chevron_right, color: onBg, size: 26),
            onPressed: _chapterIndex < chapterCount - 1 && !loading
                ? () => widget.appState.openMangaChapter(_chapterIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
