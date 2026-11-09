/// Mobile implementation of the embedded PDF viewer.
///
/// Renders the paper's PDF in-app with [pdfx]: the PDF bytes are fetched
/// over HTTP and handed to `PdfDocument.openData`, then shown in a
/// pinch-to-zoom [PdfViewPinch] with a page indicator. Only ever imported
/// on `dart:io` platforms (see `pdf_view.dart`); web keeps the iframe
/// viewer, so this file is never compiled for web.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

/// Returns a widget rendering the PDF at [url] in-app.
Widget buildPdfView(String url) => _MobilePdfView(url: url);

class _MobilePdfView extends StatefulWidget {
  const _MobilePdfView({required this.url});

  final String url;

  @override
  State<_MobilePdfView> createState() => _MobilePdfViewState();
}

class _MobilePdfViewState extends State<_MobilePdfView> {
  late final PdfControllerPinch _controller;
  int _page = 1;
  int? _pagesCount;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openData(_fetchPdf(widget.url)),
    );
  }

  /// Fetches the PDF bytes. A non-200 (e.g. Cloudinary 401 while the PDF
  /// delivery toggle is still off) throws with the status, which the
  /// error view below surfaces with a retry.
  Future<Uint8List> _fetchPdf(String url) async {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Could not load the PDF (HTTP ${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  void _retry() {
    _controller.loadDocument(PdfDocument.openData(_fetchPdf(widget.url)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_pagesCount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Page $_page of $_pagesCount',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: PdfViewPinch(
            controller: _controller,
            backgroundDecoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            onDocumentLoaded: (doc) {
              if (!mounted) return;
              setState(() => _pagesCount = doc.pagesCount);
            },
            onPageChanged: (page) {
              if (!mounted) return;
              setState(() => _page = page);
            },
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error) => _buildError(theme, error),
            ),
          ),
        ),
      ],
    );
  }

  /// Error card: the raw failure plus a retry, and — for a 401 — the
  /// Cloudinary toggle that causes it.
  Widget _buildError(ThemeData theme, Exception? error) {
    final message = error?.toString() ?? 'Could not load the PDF.';
    final is401 = message.contains('401');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📄', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (is401) ...[
              const SizedBox(height: 8),
              Text(
                'A 401 usually means Cloudinary is still blocking PDF delivery: Settings → Security → Allow delivery of PDF and ZIP files.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _retry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
