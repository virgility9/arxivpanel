/// Reader customization settings: the manga/comics reader (per
/// series, like Tachiyomi/Mihon — "For this series") and the e-book /
/// novel text reader (one set for all books, like a Kindle).
///
/// Stored in Firestore under the user's doc so they survive sign-out
/// and a new phone; signed-out readers keep them in memory only.
/// Every `fromJson` is defensive — an unknown or missing value falls
/// back to the default, so an old or hand-edited doc can never break
/// the reader.
library;

import 'dart:ui' show BoxFit;

/// Manga reading mode. `def` is Tachiyomi's default: paged, right to
/// left (manga reads right to left).
enum MangaReadingMode {
  def,
  pagedLtr,
  pagedRtl,
  pagedVertical,
  longStrip,
  longStripGaps,
}

/// Screen rotation while the manga reader is open. Applied with
/// SystemChrome when the reader opens or the setting changes;
/// restored when the reader closes.
enum ReaderRotation {
  def,
  free,
  portrait,
  landscape,
  lockedPortrait,
  lockedLandscape,
  reversePortrait,
}

/// Which screen areas turn pages on tap. `def` is edge thirds
/// (left = previous, right = next, centre toggles the menus).
enum TapZones { def, rightAndLeft, disabled }

/// Flips the tap-zone directions (for left-handed reading).
enum InvertTapZones { none, horizontal, vertical, both }

/// How a manga page fits the screen. Smart fit is contain: the whole
/// page, never cropped.
enum MangaScaleType {
  fitScreen,
  stretch,
  fitWidth,
  fitHeight,
  originalSize,
  smartFit,
}

/// Reader background. `auto` follows the app theme.
enum ReaderBackground { black, gray, white, auto }

/// Colour tint over the page (Custom filter tab). Sepia/warm/cool are
/// preset tints — there is no colour picker in v1.
enum PageTint { none, sepia, warm, cool }

/// Text reader font family. Generic families — they resolve to the
/// platform serif/sans/mono on Android, iOS and web.
enum BookFontFamily { serif, sans, mono }

/// Text reader line height.
enum BookLineHeight { compact, normal, relaxed }

/// Text reader alignment.
enum BookAlignment { left, justify }

/// Text reader theme. `auto` follows the app theme.
enum BookReadingTheme { auto, paper, dark, sepia }

/// Text reader side margins.
enum BookMargins { narrow, normal, wide }

T _enumValue<T>(List<T> values, dynamic raw, T fallback) {
  if (raw is String) {
    for (final v in values) {
      if ((v as Enum).name == raw) return v;
    }
  }
  return fallback;
}

double _doubleValue(dynamic raw, double fallback) {
  if (raw is num) return raw.toDouble();
  return fallback;
}

bool _boolValue(dynamic raw, bool fallback) {
  if (raw is bool) return raw;
  return fallback;
}

/// Customization for one manga series. `const` defaults so the reader
/// works with no saved doc at all.
class MangaReaderSettings {
  const MangaReaderSettings({
    this.readingMode = MangaReadingMode.def,
    this.rotation = ReaderRotation.def,
    this.tapZones = TapZones.def,
    this.invertTapZones = InvertTapZones.none,
    this.scaleType = MangaScaleType.fitScreen,
    this.background = ReaderBackground.black,
    this.showPageNumber = true,
    this.fullscreen = true,
    this.showActionsOnLongTap = true,
    this.animateTransitions = true,
    this.brightnessEnabled = false,
    this.brightness = 100,
    this.grayscale = false,
    this.inverted = false,
    this.tint = PageTint.none,
  });

  final MangaReadingMode readingMode;
  final ReaderRotation rotation;
  final TapZones tapZones;
  final InvertTapZones invertTapZones;
  final MangaScaleType scaleType;
  final ReaderBackground background;
  final bool showPageNumber;
  final bool fullscreen;
  final bool showActionsOnLongTap;
  final bool animateTransitions;
  final bool brightnessEnabled;

  /// 0–100. 100 is full brightness (no dimming).
  final double brightness;
  final bool grayscale;
  final bool inverted;
  final PageTint tint;

  /// True when the reader is paged (any direction), false for the two
  /// long-strip modes.
  bool get isPaged => readingMode == MangaReadingMode.def ||
      readingMode == MangaReadingMode.pagedLtr ||
      readingMode == MangaReadingMode.pagedRtl ||
      readingMode == MangaReadingMode.pagedVertical;

  /// True when the two pages are side by side in one strip.
  bool get isLongStrip => !isPaged;

  /// Long strip with a gap between pages.
  bool get hasStripGaps => readingMode == MangaReadingMode.longStripGaps;

  /// The effective paged direction: `def` resolves to right to left.
  bool get isRtl =>
      readingMode == MangaReadingMode.def ||
      readingMode == MangaReadingMode.pagedRtl;

  /// Vertical paging (swipe up/down instead of left/right).
  bool get isVerticalPaging =>
      readingMode == MangaReadingMode.pagedVertical;

  /// The BoxFit for [scaleType].
  BoxFit get fit => switch (scaleType) {
    MangaScaleType.fitScreen => BoxFit.contain,
    MangaScaleType.stretch => BoxFit.fill,
    MangaScaleType.fitWidth => BoxFit.fitWidth,
    MangaScaleType.fitHeight => BoxFit.fitHeight,
    MangaScaleType.originalSize => BoxFit.none,
    MangaScaleType.smartFit => BoxFit.contain,
  };

  /// Dim overlay opacity for the custom brightness (0 at 100).
  double get dimOpacity =>
      brightnessEnabled ? ((100 - brightness.clamp(0, 100).toDouble()) / 100) * 0.85 : 0;

  MangaReaderSettings copyWith({
    MangaReadingMode? readingMode,
    ReaderRotation? rotation,
    TapZones? tapZones,
    InvertTapZones? invertTapZones,
    MangaScaleType? scaleType,
    ReaderBackground? background,
    bool? showPageNumber,
    bool? fullscreen,
    bool? showActionsOnLongTap,
    bool? animateTransitions,
    bool? brightnessEnabled,
    double? brightness,
    bool? grayscale,
    bool? inverted,
    PageTint? tint,
  }) {
    return MangaReaderSettings(
      readingMode: readingMode ?? this.readingMode,
      rotation: rotation ?? this.rotation,
      tapZones: tapZones ?? this.tapZones,
      invertTapZones: invertTapZones ?? this.invertTapZones,
      scaleType: scaleType ?? this.scaleType,
      background: background ?? this.background,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      fullscreen: fullscreen ?? this.fullscreen,
      showActionsOnLongTap:
          showActionsOnLongTap ?? this.showActionsOnLongTap,
      animateTransitions: animateTransitions ?? this.animateTransitions,
      brightnessEnabled: brightnessEnabled ?? this.brightnessEnabled,
      brightness: brightness ?? this.brightness,
      grayscale: grayscale ?? this.grayscale,
      inverted: inverted ?? this.inverted,
      tint: tint ?? this.tint,
    );
  }

  Map<String, dynamic> toJson() => {
    'readingMode': readingMode.name,
    'rotation': rotation.name,
    'tapZones': tapZones.name,
    'invertTapZones': invertTapZones.name,
    'scaleType': scaleType.name,
    'background': background.name,
    'showPageNumber': showPageNumber,
    'fullscreen': fullscreen,
    'showActionsOnLongTap': showActionsOnLongTap,
    'animateTransitions': animateTransitions,
    'brightnessEnabled': brightnessEnabled,
    'brightness': brightness,
    'grayscale': grayscale,
    'inverted': inverted,
    'tint': tint.name,
  };

  static MangaReaderSettings fromJson(Map<String, dynamic> json) {
    return MangaReaderSettings(
      readingMode: _enumValue(
        MangaReadingMode.values,
        json['readingMode'],
        MangaReadingMode.def,
      ),
      rotation: _enumValue(
        ReaderRotation.values,
        json['rotation'],
        ReaderRotation.def,
      ),
      tapZones: _enumValue(TapZones.values, json['tapZones'], TapZones.def),
      invertTapZones: _enumValue(
        InvertTapZones.values,
        json['invertTapZones'],
        InvertTapZones.none,
      ),
      scaleType: _enumValue(
        MangaScaleType.values,
        json['scaleType'],
        MangaScaleType.fitScreen,
      ),
      background: _enumValue(
        ReaderBackground.values,
        json['background'],
        ReaderBackground.black,
      ),
      showPageNumber: _boolValue(json['showPageNumber'], true),
      fullscreen: _boolValue(json['fullscreen'], true),
      showActionsOnLongTap: _boolValue(json['showActionsOnLongTap'], true),
      animateTransitions: _boolValue(json['animateTransitions'], true),
      brightnessEnabled: _boolValue(json['brightnessEnabled'], false),
      brightness: _doubleValue(json['brightness'], 100),
      grayscale: _boolValue(json['grayscale'], false),
      inverted: _boolValue(json['inverted'], false),
      tint: _enumValue(PageTint.values, json['tint'], PageTint.none),
    );
  }
}

/// Customization for the e-book / novel text reader. One set for all
/// books (the e-reader norm), stored as a single Firestore doc.
class BookReaderSettings {
  const BookReaderSettings({
    this.fontSize = 17,
    this.fontFamily = BookFontFamily.serif,
    this.lineHeight = BookLineHeight.normal,
    this.align = BookAlignment.left,
    this.readingTheme = BookReadingTheme.auto,
    this.margins = BookMargins.normal,
    this.brightnessEnabled = false,
    this.brightness = 100,
  });

  /// 12–28.
  final double fontSize;
  final BookFontFamily fontFamily;
  final BookLineHeight lineHeight;
  final BookAlignment align;
  final BookReadingTheme readingTheme;
  final BookMargins margins;
  final bool brightnessEnabled;

  /// 0–100. 100 is full brightness (no dimming).
  final double brightness;

  /// Generic font family name — resolves on Android, iOS and web.
  String get fontFamilyName => switch (fontFamily) {
    BookFontFamily.serif => 'serif',
    BookFontFamily.sans => 'sans-serif',
    BookFontFamily.mono => 'monospace',
  };

  double get lineHeightValue => switch (lineHeight) {
    BookLineHeight.compact => 1.5,
    BookLineHeight.normal => 1.8,
    BookLineHeight.relaxed => 2.2,
  };

  double get marginValue => switch (margins) {
    BookMargins.narrow => 16,
    BookMargins.normal => 24,
    BookMargins.wide => 40,
  };

  /// Dim overlay opacity for the custom brightness (0 at 100).
  double get dimOpacity =>
      brightnessEnabled ? ((100 - brightness.clamp(0, 100).toDouble()) / 100) * 0.85 : 0;

  BookReaderSettings copyWith({
    double? fontSize,
    BookFontFamily? fontFamily,
    BookLineHeight? lineHeight,
    BookAlignment? align,
    BookReadingTheme? readingTheme,
    BookMargins? margins,
    bool? brightnessEnabled,
    double? brightness,
  }) {
    return BookReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      align: align ?? this.align,
      readingTheme: readingTheme ?? this.readingTheme,
      margins: margins ?? this.margins,
      brightnessEnabled: brightnessEnabled ?? this.brightnessEnabled,
      brightness: brightness ?? this.brightness,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'fontFamily': fontFamily.name,
    'lineHeight': lineHeight.name,
    'align': align.name,
    'readingTheme': readingTheme.name,
    'margins': margins.name,
    'brightnessEnabled': brightnessEnabled,
    'brightness': brightness,
  };

  static BookReaderSettings fromJson(Map<String, dynamic> json) {
    return BookReaderSettings(
      fontSize: _doubleValue(json['fontSize'], 17).clamp(12, 28).toDouble(),
      fontFamily: _enumValue(
        BookFontFamily.values,
        json['fontFamily'],
        BookFontFamily.serif,
      ),
      lineHeight: _enumValue(
        BookLineHeight.values,
        json['lineHeight'],
        BookLineHeight.normal,
      ),
      align: _enumValue(
        BookAlignment.values,
        json['align'],
        BookAlignment.left,
      ),
      readingTheme: _enumValue(
        BookReadingTheme.values,
        json['readingTheme'],
        BookReadingTheme.auto,
      ),
      margins: _enumValue(
        BookMargins.values,
        json['margins'],
        BookMargins.normal,
      ),
      brightnessEnabled: _boolValue(json['brightnessEnabled'], false),
      brightness: _doubleValue(json['brightness'], 100),
    );
  }
}
