/// Windowed pagination bar: « ‹ 1 … 4 5 [6] 7 8 … 40 › »
///
/// Shows the first and last page, a window around the current page and
/// ellipses for the gaps. Built from core widgets only. [page] is 0-based.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shared.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.palette,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final AppPalette palette;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  /// Page numbers (1-based) to show; `null` marks an ellipsis.
  List<int?> _items(int radius) {
    final current = page + 1;
    final shown = <int>{
      1,
      pageCount,
      for (var i = current - radius; i <= current + radius; i++)
        if (i >= 1 && i <= pageCount) i,
    }.toList()
      ..sort();
    final out = <int?>[];
    for (var i = 0; i < shown.length; i++) {
      if (i > 0) {
        final gap = shown[i] - shown[i - 1];
        if (gap == 2) {
          out.add(shown[i] - 1); // a lone hidden page: show it, not "…"
        } else if (gap > 2) {
          out.add(null);
        }
      }
      out.add(shown[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final narrow = MediaQuery.of(context).size.width < 700;
    final items = _items(narrow ? 1 : 2);
    final atStart = page <= 0;
    final atEnd = page >= pageCount - 1;

    // A Row, not a Wrap: a pager is one row by definition. The Wrap
    // shrank to its content width under the Library's Center and laid
    // the buttons out as a vertical column — the « ‹ pair on one line,
    // one page number per line, then the › » pair. A Row with
    // MainAxisSize.max takes the full width the stretch Column offers
    // and centers the buttons in a single line. Buttons shrink on
    // narrow screens so a many-page bar still fits a 320dp phone
    // (4 arrows + 3 numbers + 2 ellipses is about 280px at 32px).
    final gap = SizedBox(width: narrow ? 2 : 6);
    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) children.add(gap);
      children.add(w);
    }

    add(_arrow(Icons.keyboard_double_arrow_left, 'First page',
        atStart ? null : () => onPageChanged(0), narrow));
    add(_arrow(Icons.chevron_left, 'Previous page',
        atStart ? null : () => onPageChanged(page - 1), narrow));
    for (final n in items) {
      add(n == null ? _ellipsis(narrow) : _number(n, narrow));
    }
    add(_arrow(Icons.chevron_right, 'Next page',
        atEnd ? null : () => onPageChanged(page + 1), narrow));
    add(_arrow(Icons.keyboard_double_arrow_right, 'Last page',
        atEnd ? null : () => onPageChanged(pageCount - 1), narrow));

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _ellipsis(bool narrow) {
    return SizedBox(
      width: narrow ? 20 : 28,
      child: Center(
        child: Text('…',
            style: bodyStyle(palette, size: 14, color: palette.c.faint)),
      ),
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onTap,
      bool narrow) {
    final c = palette.c;
    final size = narrow ? 32.0 : 40.0;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: narrow ? 18 : 22),
      color: c.text,
      disabledColor: c.fainter,
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.zero,
    );
  }

  Widget _number(int n, bool narrow) {
    final c = palette.c;
    final a = palette.accent;
    final selected = n == page + 1;
    final size = narrow ? 32.0 : 40.0;
    return InkWell(
      onTap: selected ? null : () => onPageChanged(n - 1),
      customBorder: const CircleBorder(),
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: selected ? BoxShape.circle : BoxShape.rectangle,
          color: selected ? a.accent.withValues(alpha: 0.15) : null,
        ),
        child: Text(
          '$n',
          style: bodyStyle(
            palette,
            size: 15,
            color: selected ? a.accent : c.text,
            weight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
