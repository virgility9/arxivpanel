/// Auth modal ported from `src/components/AuthModal.tsx`.
///
/// Presented as a modal bottom sheet (matching the web app's bottom-anchored
/// sheet with drag handle and gold corner accents). Sign-in uses email +
/// password against Firebase Auth; registration adds a username field (the
/// avatar is picked server-side by [AuthRepository.signUp]).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'shared.dart';

enum AuthMode { login, register }

class AuthDialog extends StatefulWidget {
  const AuthDialog({
    super.key,
    required this.mode,
    required this.appState,
    required this.theme,
  });

  final AuthMode mode;
  final AppState appState;
  final ThemeProvider theme;

  /// Shows the dialog as a bottom sheet, mirroring the web modal.
  static Future<void> show(
    BuildContext context, {
    required AuthMode mode,
    required AppState appState,
    required ThemeProvider theme,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthDialog(mode: mode, appState: appState, theme: theme),
    );
  }

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  late AuthMode _mode;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  late final TapGestureRecognizer _modeToggleRecognizer;
  String _error = '';
  bool _loading = false;
  bool _obscured = true;
  bool _resetSent = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _modeToggleRecognizer = TapGestureRecognizer()..onTap = _toggleMode;
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
      _error = '';
    });
  }

  @override
  void dispose() {
    _modeToggleRecognizer.dispose();
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _error = '';
      _loading = true;
    });

    final email = _email.text.trim();
    final password = _password.text;
    final username = _username.text.trim();

    // Client-side validation before hitting Firebase.
    String? validationError;
    if (email.isEmpty || password.isEmpty) {
      validationError = 'Email and password are required.';
    } else if (!email.contains('@')) {
      validationError = 'Enter a valid email address.';
    } else if (_mode == AuthMode.register && username.isEmpty) {
      validationError = 'Please choose a display name.';
    } else if (_mode == AuthMode.register && password.length < 6) {
      validationError = 'Password must be at least 6 characters.';
    }
    if (validationError != null) {
      setState(() {
        _error = validationError!;
        _loading = false;
      });
      return;
    }

    final err = _mode == AuthMode.login
        ? await widget.appState.signIn(email: email, password: password)
        : await widget.appState.signUp(
            username: username,
            email: email,
            password: password,
          );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      Navigator.of(context).pop();
    }
  }

  /// Sends a password-reset email for the address currently in the email
  /// field. Login mode only.
  Future<void> _sendReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    final err = await widget.appState.sendPasswordReset(email: email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err != null) {
        _error = err;
      } else {
        _resetSent = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final isLogin = _mode == AuthMode.login;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: maxSheetHeight),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Stack(
            children: [
              // Gold corner accents
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: a.accent, width: 2),
                      left: BorderSide(color: a.accent, width: 2),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: a.accent, width: 2),
                      right: BorderSide(color: a.accent, width: 2),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isLogin ? 'Welcome back' : 'Join ArxivPanel',
                      style: displayStyle(palette, size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLogin
                          ? 'Sign in to your research account'
                          : 'Create your researcher profile',
                      style: bodyStyle(palette, size: 13, color: c.muted),
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    if (!isLogin) ...[
                      LabeledField(
                        palette: palette,
                        label: 'Display Name',
                        child: TextField(
                          controller: _username,
                          style: TextStyle(color: c.text, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Dr. Ada Lovelace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    LabeledField(
                      palette: palette,
                      label: 'Email',
                      child: TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: TextStyle(color: c.text, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'you@institution.edu',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LabeledField(
                      palette: palette,
                      label: 'Password',
                      child: TextField(
                        controller: _password,
                        obscureText: _obscured,
                        autofillHints: isLogin
                            ? const [AutofillHints.password]
                            : const [AutofillHints.newPassword],
                        style: TextStyle(color: c.text, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            // 44px minimum touch target.
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: c.muted,
                            ),
                            tooltip: _obscured
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                                () => _obscured = !_obscured),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                        ],
                      ),
                    ),
                    // Password reset lives in login mode only.
                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetSent ? null : _sendReset,
                          child: Text(
                            _resetSent
                                ? 'Reset email sent ✓'
                                : 'Forgot password?',
                          ),
                        ),
                      ),
                    ],
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(message: _error),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: GoldButton(
                        palette: palette,
                        label: isLogin ? 'Sign In' : 'Create Account',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text.rich(
                      TextSpan(
                        text: isLogin ? 'No account? ' : 'Already registered? ',
                        style: bodyStyle(palette, size: 13, color: c.muted),
                        children: [
                          TextSpan(
                            text: isLogin ? 'Register here' : 'Sign in',
                            style: TextStyle(
                              color: a.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            recognizer: _modeToggleRecognizer,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
