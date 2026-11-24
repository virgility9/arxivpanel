/// Small shared controls for the two reader settings sheets (manga
/// and books): pill option chips, check rows and slider rows in the
/// app's palette language — selected pill is gold, the rest are
/// outlined. The sheets stay separate; only the controls are shared.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

/// One option in a pill row. [label] is the text on the pill,
/// [selected] fills it gold, [onTap] applies the choice.
class ReaderOptionPill extends StatelessWidget {
  const ReaderOptionPill({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final a = palette.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? a.accent : Colors.transparent,
            border: Border.all(
              color: selected ? a.accent : c.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: bodyStyle(
              palette,
              size: 13,
              color: selected ? a.accentFg : c.text,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of option pills (wraps onto more lines when it must).
class ReaderOptionRow extends StatelessWidget {
  const ReaderOptionRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

/// Section label + content, like the detail screen's sections.
class ReaderSection extends StatelessWidget {
  const ReaderSection({
    super.key,
    required this.palette,
    required this.title,
    required this.child,
  });

  final AppPalette palette;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(palette: palette, text: title),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// A checkbox row: tap anywhere on the row to toggle.
class ReaderCheckRow extends StatelessWidget {
  const ReaderCheckRow({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AppPalette palette;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final a = palette.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                  activeColor: a.accent,
                  checkColor: a.accentFg,
                  side: BorderSide(color: c.border, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: bodyStyle(palette, size: 14, color: c.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider row with the current value shown at the right.
class ReaderSliderRow extends StatelessWidget {
  const ReaderSliderRow({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final AppPalette palette;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;

  /// Null disables the slider (greyed out).
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final a = palette.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: bodyStyle(palette, size: 14, color: c.text),
              ),
            ),
            Text(
              valueLabel,
              style: monoStyle(palette, size: 12, color: c.faint),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: a.accent,
          inactiveColor: c.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Opens a reader settings sheet: a bottom sheet with a drag handle.
Future<void> showReaderSettingsSheet({
  required BuildContext context,
  required ThemeProvider theme,
  required Widget child,
}) {
  final p = theme.palette;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}
