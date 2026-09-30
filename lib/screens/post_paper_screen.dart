/// Paper submission screen, ported from `src/components/PostPaper.tsx`.
///
/// Auth-gated form: unauthenticated users get a sign-in prompt, a successful
/// submit shows a confirmation, otherwise a full submission form with cover
/// picker, title, abstract, field/pages, institution, tags, PDF URL and a
/// submitter card.
///
/// Note: the web app's file uploads (cover image, PDF file) are not portable
/// to Flutter, so both are represented as URL text fields here.
library;

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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
  late final TextEditingController _customCover;
  late final TextEditingController _pdfUrl;

  String _field = 'Machine Learning';
  int _presetIndex = 0;
  Map<String, String> _errors = {};
  bool _loading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _abstract = TextEditingController();
    _pages = TextEditingController();
    _institution = TextEditingController();
    _tags = TextEditingController();
    _customCover = TextEditingController();
    _pdfUrl = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _abstract.dispose();
    _pages.dispose();
    _institution.dispose();
    _tags.dispose();
    _customCover.dispose();
    _pdfUrl.dispose();
    super.dispose();
  }

  String get _effectiveCover {
    final custom = _customCover.text.trim();
    return custom.isNotEmpty ? custom : AppConstants.presetCovers[_presetIndex];
  }

  void _handleSubmit() {
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
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      final user = widget.appState.user!;
      final pdfRaw = _pdfUrl.text.trim();
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
        coverImage: _effectiveCover,
        publishedAt: DateTime.now().toIso8601String().split('T').first,
        pages: pages!,
        views: 0,
        reactions: const {},
        comments: const [],
        institution: institution,
        year: DateTime.now().year.toString(),
        pdfUrl: pdfRaw.isEmpty ? null : pdfRaw,
        status: PaperStatus.pending,
        submittedAt: DateTime.now(),
      );
      await widget.appState.submitPaper(paper);
      setState(() {
        _loading = false;
        _submitted = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final user = widget.appState.user;

    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: user == null
                  ? _buildSignInPrompt(p)
                  : _submitted
                  ? _buildSuccess(p)
                  : _buildForm(p, user),
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

  Widget _buildForm(AppPalette p, AppUser user) {
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
        // Cover
        _buildCoverSection(p),
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
        // Field + Pages
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                palette: p,
                label: 'Field',
                child: DropdownButtonFormField<String>(
                  initialValue: _field,
                  dropdownColor: p.c.surface,
                  style: TextStyle(color: p.c.text, fontSize: 14),
                  items: fields
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _field = v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: LabeledField(
                palette: p,
                label: 'Pages',
                error: _errors['pages'],
                child: TextField(
                  controller: _pages,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '42'),
                ),
              ),
            ),
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
            TextField(
              controller: _pdfUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://…/paper.pdf',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Text('📁', style: TextStyle(fontSize: 18)),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The web app uploads a PDF file directly — paste a URL here as the portable equivalent.',
              style: monoStyle(p, size: 9, color: p.c.faint),
            ),
          ],
        ),
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

  Widget _buildCoverSection(AppPalette p) {
    final c = p.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(palette: p, text: 'Cover Image'),
        const SizedBox(height: 10),
        // Large preview of the effective cover
        NetImage(
          url: _effectiveCover,
          width: 160,
          height: 220,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 12),
        // Preset thumbnails
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(AppConstants.presetCovers.length, (idx) {
            final selected =
                _customCover.text.trim().isEmpty && _presetIndex == idx;
            return GestureDetector(
              onTap: () => setState(() => _presetIndex = idx),
              child: Container(
                width: 52,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? p.accent.accent : c.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: NetImage(
                    url: AppConstants.presetCovers[idx],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customCover,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Custom cover URL (optional)',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The web app uploads a cover image file — paste an image URL here as the portable equivalent.',
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
