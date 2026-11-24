/// In-app PDF viewer for one comic issue: the resolved issue PDF in
/// the existing embedded viewer (pdfx on mobile, iframe on web). The
/// system back button returns to the detail screen, same as the back
/// arrow.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import '../widgets/pdf_view.dart';
import '../widgets/shared.dart';

class CatalogPdfScreen extends StatefulWidget {
  const CatalogPdfScreen({
    super.key,
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<CatalogPdfScreen> createState() => _CatalogPdfScreenState();
}

class _CatalogPdfScreenState extends State<CatalogPdfScreen> {
  @override
  void initState() {
    super.initState();
    widget.appState.setInnerBackHandler(_backToDetail);
  }

  @override
  void dispose() {
    widget.appState.setInnerBackHandler(null);
    super.dispose();
  }

  void _backToDetail() {
    widget.appState.navigate(AppView.catalogDetail);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final item = widget.appState.selectedCatalogItem;
        final pdfUrl = item?.pdfUrl;
        if (item == null || pdfUrl == null) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
              child: EmptyState(
                palette: p,
                icon: Icons.picture_as_pdf,
                title: 'No issue to show',
                sub: 'Go back and tap Read again.',
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: back + issue title.
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
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
                    icon: Icon(Icons.arrow_back, color: c.text, size: 22),
                    onPressed: _backToDetail,
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: displayStyle(p,
                          size: 16, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: buildPdfView(pdfUrl)),
          ],
        );
      },
    );
  }
}
