/// Paper submission screen, ported from `src/components/PostPaper.tsx`.
///
/// Auth-gated form: unauthenticated users get a sign-in prompt, a successful
/// submit shows a confirmation, otherwise a full submission form with title,
/// abstract, field/pages, institution, tags, a PDF file picker (uploaded to
/// Cloudinary on submit) and a submitter card. The cover is always the first
/// page of the attached PDF — there is no manual cover picker.
library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/file_pick.dart';
import '../widgets/pdf_view.dart';
import '../widgets/shared.dart';

class PostPaperScreen extends StatefulWidget {
  const PostPaperScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<PostPaperScreen> createState() => _PostPaperScreenState();
}

class _PostPaperScreenState extends State<PostPaperScreen> {
  late final TextEditingController _title;
  late final TextEditingController _abstract;
  late final TextEditingController _pages;
  late final TextEditingController _institution;
  late final TextEditingController _tags;

  String _field = 'Machine Learning';
  Map<String, String> _errors = {};
  bool _loading = false;
  bool _submitted = false;

  /// Picked PDF (device storage), uploaded to Cloudinary on submit.
  Uint8List? _pdfBytes;
  String? _pdfName;

  /// Web-only blob URL for the picked PDF, plus a first-page preview widget
  /// built once per picked file. The widget is cached because every
  /// [buildPdfView] call registers a new iframe view — rebuilding it on
  /// every setState would reload the PDF constantly.
  String? _pdfPreviewUrl;
  Widget? _pdfCoverPreview;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _abstract = TextEditingController();
    _pages = TextEditingController();
    _institution = TextEditingController();
    _tags = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _abstract.dispose();
    _pages.dispose();
    _institution.dispose();
    _tags.dispose();
    _revokePreviewUrl();
    super.dispose();
  }

  /// Human-readable size of the picked PDF (e.g. "2.4 MB").
  String get _pdfSizeLabel {
    final bytes = _pdfBytes;
    if (bytes == null) return '';
    if (bytes.length < 1024) return '${bytes.length} B';
    final kb = bytes.length / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _handleSubmit() async {
    final errs = <String, String>{};
    final title = _title.text.trim();
    final abstract = _abstract.text.trim();
    final institution = _institution.text.trim();
    final pagesStr = _pages.text.trim();
    final pages = int.tryParse(pagesStr);
    if (title.isEmpty) errs['title'] = 'Title is required';
    if (abstract.isEmpty || abstract.length < 80) {
      errs['abstract'] = 'Abstract must be at least 80 characters';
    }
    if (institution.isEmpty) errs['institution'] = 'Institution is required';
    if (pagesStr.isEmpty || pages == null || pages < 1) {
      errs['pages'] = 'Valid page count required';
    }
    setState(() => _errors = errs);
    if (errs.isNotEmpty) return;

    setState(() => _loading = true);
    final user = widget.appState.user!;
    final paper = Paper(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: user.username,
      authorId: user.id,
      authorAvatar: user.avatar,
      abstract: abstract,
      field: _field,
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      coverImage: '', // replaced by the PDF's first page after upload below
      publishedAt: DateTime.now().toIso8601String().split('T').first,
      pages: pages!,
      views: 0,
      reactions: const {},
      comments: const [],
      institution: institution,
      year: DateTime.now().year.toString(),
      pdfUrl: null, // attached after the Storage upload below
      status: PaperStatus.pending,
      submittedAt: DateTime.now(),
    );
    // The paper doc is created first, then the PDF uploads to Cloudinary
    // (free tier); the PDF's URL and its auto-generated cover (the first
    // page) are then attached to the paper.
    final paperId = await widget.appState.submitPaper(paper);
    if (paperId != null && _pdfBytes != null) {
      final uploaded = await widget.appState.uploadPaperPdf(
        _pdfBytes!,
        _pdfName ?? 'paper.pdf',
      );
      if (uploaded != null) {
        await widget.appState.setPaperPdfAndCover(
          paperId,
          uploaded.fileUrl,
          uploaded.coverUrl,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
    });
  }

  /// Revokes the picked PDF's blob URL (web only). Called when the PDF is
  /// removed, replaced, or the screen is disposed.
  void _revokePreviewUrl() {
    final url = _pdfPreviewUrl;
    _pdfPreviewUrl = null;
    _pdfCoverPreview = null;
    if (url != null && kIsWeb) {
      web.URL.revokeObjectURL(url);
    }
  }

  /// Picks a PDF from device storage.
  Future<void> _pickPdf() async {
    try {
      final picked = await pickSingleFile(PickKind.pdf);
      // Null = the user cancelled.
      if (picked == null) return;
      setState(() {
        _revokePreviewUrl();
        _pdfBytes = picked.bytes;
        _pdfName = picked.name;
        if (kIsWeb) {
          final blob = web.Blob(
            [Uint8List.fromList(picked.bytes).buffer.toJS].toJS,
            web.BlobPropertyBag(type: 'application/pdf'),
          );
          _pdfPreviewUrl = web.URL.createObjectURL(blob);
          _pdfCoverPreview = buildPdfView(_pdfPreviewUrl!);
        }
      });
    } catch (e) {
      widget.appState.showToast(
        'Could not read the PDF (${shortError(e)})',
        '⚠️',
      );
    }
  }

  /// Previews the picked PDF in a dialog (web) — no upload yet. Reuses the
  /// same blob URL as the inline cover preview.
  void _previewPdf() {
    if (!kIsWeb) {
      widget.appState.showToast('PDF preview is only available on web', '⚠️');
      return;
    }
    final url = _pdfPreviewUrl;
    if (url == null) return;
    final p = widget.theme.palette;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          _pdfName ?? 'PDF preview',
          style: displayStyle(p, size: 16, weight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 720,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: buildPdfView(url),
        ),
        actions: [
          GoldButton(
            palette: p,
            label: 'Close',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    // No revoke here: the URL is shared with the cover preview and is
    // revoked when the PDF is removed, replaced, or the screen closes.
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final user = widget.appState.user;

    // NOTE: no nested Scaffold — AppShell already provides one.
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: user == null
                ? _buildSignInPrompt(p)
                : _submitted
                ? _buildSuccess(p)
                : _buildForm(
                    p,
                    user,
                    MediaQuery.of(context).size.width < 560,
                  ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- signed-out

  Widget _buildSignInPrompt(AppPalette p) {
    final c = p.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📄', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            'Submit Your Research',
            style: displayStyle(p, size: 26, weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to share your paper with the research community.',
            style: bodyStyle(p, size: 15, color: c.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              palette: p,
              label: 'Sign In to Continue',
              onPressed: widget.onAuthPrompt,
              minHeight: 52,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- success

  Widget _buildSuccess(AppPalette p) {
    final c = p.c;
    final a = p.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📬', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Paper Submitted!',
            style: displayStyle(p, size: 28, weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: a.accent.withValues(alpha: 0.1),
              border: Border.all(color: a.accent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: a.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Review'.toUpperCase(),
                  style: monoStyle(
                    p,
                    size: 12,
                    color: a.accent,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your paper is under admin review. Once approved, it will appear in the library.',
            style: bodyStyle(p, size: 15, color: c.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              palette: p,
              label: 'Back to Library',
              onPressed: () => widget.appState.navigate(AppView.library),
              minHeight: 52,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- form

  Widget _fieldField(AppPalette p, List<String> fields) {
    return LabeledField(
      palette: p,
      label: 'Field',
      child: DropdownButtonFormField<String>(
        initialValue: _field,
        isExpanded: true,
        dropdownColor: p.c.surface,
        style: TextStyle(color: p.c.text, fontSize: 14),
        items: fields
            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _field = v);
        },
      ),
    );
  }

  Widget _pagesField(AppPalette p) {
    return LabeledField(
      palette: p,
      label: 'Pages',
      error: _errors['pages'],
      child: TextField(
        controller: _pages,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '42'),
      ),
    );
  }
  Widget _buildForm(AppPalette p, AppUser user, bool narrow) {
    final fields = AppConstants.fields.where((f) => f != 'All Fields').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            GhostButton(
              palette: p,
              label: '←',
              minHeight: 44,
              onPressed: () => widget.appState.navigate(AppView.library),
            ),
            const SizedBox(width: 12),
            Text(
              'Submit a Paper',
              style: displayStyle(p, size: 22, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Title
        LabeledField(
          palette: p,
          label: 'Paper Title',
          error: _errors['title'],
          child: TextField(
            controller: _title,
            decoration: const InputDecoration(
              hintText: 'The full title of your research paper or thesis',
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Abstract
        LabeledField(
          palette: p,
          label: 'Abstract',
          error: _errors['abstract'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _abstract,
                minLines: 5,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Comprehensive abstract (min 80 chars)…',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_abstract.text.length} / 80 min',
                style: monoStyle(
                  p,
                  size: 10,
                  color: _abstract.text.length < 80
                      ? const Color(0xFFE06B6B)
                      : p.c.faint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Field + Pages — side by side on wide screens, stacked on narrow
        // screens so the dropdowns never get cramped.
        if (narrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldField(p, fields),
              const SizedBox(height: 18),
              _pagesField(p),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _fieldField(p, fields)),
              const SizedBox(width: 14),
              Expanded(child: _pagesField(p)),
            ],
          ),
        const SizedBox(height: 18),
        // Institution
        LabeledField(
          palette: p,
          label: 'Institution',
          error: _errors['institution'],
          child: TextField(
            controller: _institution,
            decoration: const InputDecoration(
              hintText: 'MIT, Stanford, ETH Zürich…',
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Tags
        LabeledField(
          palette: p,
          label: 'Tags (comma-separated)',
          child: TextField(
            controller: _tags,
            decoration: const InputDecoration(
              hintText: 'deep learning, NLP, attention…',
            ),
          ),
        ),
        const SizedBox(height: 18),
        // PDF URL
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionLabel(palette: p, text: 'Paper File (PDF)'),
                Text(
                  ' — optional',
                  style: bodyStyle(p, size: 10, color: p.c.fainter),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_pdfBytes == null)
              // No file picked yet — open the device file chooser.
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickPdf,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                  'Choose PDF from device',
                  style: bodyStyle(p, size: 13, color: p.c.text),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.c.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  minimumSize: const Size.fromHeight(44),
                ),
              )
            else
              // Picked file: name, size, preview and remove actions.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.c.surface,
                  border: Border.all(color: p.c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 32,
                      color: Color(0xFFE06B6B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pdfName ?? 'paper.pdf',
                            style: bodyStyle(
                              p,
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pdfSizeLabel,
                            style:
                                bodyStyle(p, size: 11, color: p.c.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _previewPdf,
                      child: Text(
                        'Preview',
                        style: bodyStyle(
                          p,
                          size: 13,
                          color: p.accent.accent,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _revokePreviewUrl();
                                _pdfBytes = null;
                                _pdfName = null;
                              }),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: p.c.muted,
                      ),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'The PDF is uploaded (free Cloudinary hosting) when you submit.',
              style: monoStyle(p, size: 9, color: p.c.faint),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Cover — always the first page of the attached PDF.
        _buildCoverSection(p),
        const SizedBox(height: 24),
        // Submitter card
        _buildSubmitterCard(p, user),
        const SizedBox(height: 24),
        // Submit
        SizedBox(
          width: double.infinity,
          child: GoldButton(
            palette: p,
            label: 'Submit for Review',
            loading: _loading,
            onPressed: _loading ? null : _handleSubmit,
            minHeight: 54,
          ),
        ),
      ],
    );
  }

  /// Cover preview: always the first page of the attached PDF. There is no
  /// manual cover picker — the cover is generated from the PDF on submit.
  Widget _buildCoverSection(AppPalette p) {
    final c = p.c;
    final preview = _pdfCoverPreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(palette: p, text: 'Cover'),
        const SizedBox(height: 10),
        if (_pdfBytes != null && preview != null)
          // The picked PDF's first page, rendered live as the cover.
          Container(
            width: 160,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: preview,
            ),
          )
        else
          // No PDF (or not on web): placeholder until one is picked.
          Container(
            width: 160,
            height: 220,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 40,
                      color: c.faint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pdfBytes != null
                          ? 'Cover preview is only available on web.'
                          : 'Pick a PDF above — its first page becomes the cover.',
                      textAlign: TextAlign.center,
                      style: bodyStyle(p, size: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'The cover is always the first page of your PDF, generated automatically when you submit.',
          style: monoStyle(p, size: 9, color: c.faint),
        ),
      ],
    );
  }

  Widget _buildSubmitterCard(AppPalette p, AppUser user) {
    final c = p.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AvatarImage(url: user.avatar, size: 32),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUBMITTING AS',
                style: monoStyle(p, size: 9, letterSpacing: 0.1),
              ),
              const SizedBox(height: 2),
              Text(
                user.username,
                style: bodyStyle(p, size: 13, weight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
