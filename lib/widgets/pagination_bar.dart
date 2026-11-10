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

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: narrow ? 2 : 6,
      runSpacing: 6,
      children: [
        _arrow(Icons.keyboard_double_arrow_left, 'First page',
            atStart ? null : () => onPageChanged(0)),
        _arrow(Icons.chevron_left, 'Previous page',
            atStart ? null : () => onPageChanged(page - 1)),
        for (final n in items)
          if (n == null)
            SizedBox(
              width: 28,
              child: Center(
                child: Text('…',
                    style: bodyStyle(palette, size: 14, color: palette.c.faint)),
              ),
            )
          else
            _number(n),
        _arrow(Icons.chevron_right, 'Next page',
            atEnd ? null : () => onPageChanged(page + 1)),
        _arrow(Icons.keyboard_double_arrow_right, 'Last page',
            atEnd ? null : () => onPageChanged(pageCount - 1)),
      ],
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onTap) {
    final c = palette.c;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: c.text,
      disabledColor: c.fainter,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }

  Widget _number(int n) {
    final c = palette.c;
    final a = palette.accent;
    final selected = n == page + 1;
    return InkWell(
      onTap: selected ? null : () => onPageChanged(n - 1),
      customBorder: const CircleBorder(),
      child: Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
