/// Entry point of the Arxiv Flutter app (Firebase backend edition).
///
/// Manual Firebase setup (no CLI): [DefaultFirebaseConfig] holds the web-app
/// config values pasted from the Firebase console — see FIREBASE_SETUP.md.
/// If the placeholders haven't been filled in yet, the app shows a friendly
/// "not configured" screen instead of crashing.
///
/// Boot flow: the logo splash shows immediately while Firebase initializes
/// (at least ~1.2s so the logo is actually seen), then the app swaps to the
/// shell, the setup prompt (config placeholders), or the connection screen
/// (init failed — usually no internet) with a retry button.
///
/// Hand-rolled state wiring (no third-party packages): a [ThemeProvider] and
/// an [AppState] are created once, the root widget rebuilds whenever either
/// notifies, and both are passed down the tree via constructors.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase/firebase_config.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/app_logo_image.dart';
import 'widgets/app_shell.dart';
import 'widgets/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArxivApp());
}

/// Where the app is in its startup sequence.
enum _BootPhase { splash, ready, notConfigured, initFailed }

class ArxivApp extends StatefulWidget {
  const ArxivApp({super.key});

  @override
  State<ArxivApp> createState() => _ArxivAppState();
}

class _ArxivAppState extends State<ArxivApp> {
  final ThemeProvider _theme = ThemeProvider();
  AppState? _appState;
  _BootPhase _phase = _BootPhase.splash;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onChange);
    _boot();
  }

  void _onChange() => setState(() {});

  /// Initializes Firebase in the background while the splash is showing.
  /// [AppState] is created only after init succeeds: its repositories
  /// touch `FirebaseFirestore.instance`, which throws before the default
  /// app exists.
  Future<void> _boot() async {
    final started = DateTime.now();
    final configured = DefaultFirebaseConfig.isConfigured;
    var ready = false;
    if (configured) {
      try {
        if (kIsWeb) {
          // Web has no config file, so it needs the explicit options.
          await Firebase.initializeApp(
            options: DefaultFirebaseConfig.currentPlatform,
          );
        } else {
          // Android/iOS read their own config files (google-services.json /
          // GoogleService-Info.plist). The google-services plugin already
          // initialized the default app at startup, so passing the web
          // options here would throw ("duplicate app").
          await Firebase.initializeApp();
        }
        ready = true;
      } catch (e) {
        // Invalid values, no network, etc. — the retry screen handles it.
        debugPrint('Firebase.initializeApp failed: $e');
        ready = false;
      }
    }
    // Keep the splash visible long enough for the logo to be seen.
    const minSplash = Duration(milliseconds: 1200);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
    if (!mounted) return;
    setState(() {
      if (ready) {
        _appState ??= AppState();
        _appState!.addListener(_onChange);
        _phase = _BootPhase.ready;
      } else if (!configured) {
        _phase = _BootPhase.notConfigured;
      } else {
        _phase = _BootPhase.initFailed;
      }
    });
  }

  void _retryBoot() {
    setState(() => _phase = _BootPhase.splash);
    _boot();
  }

  @override
  void dispose() {
    _theme.removeListener(_onChange);
    _appState?.removeListener(_onChange);
    _theme.dispose();
    _appState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arxiv',
      debugShowCheckedModeBanner: false,
      theme: _theme.themeData,
      home: switch (_phase) {
        _BootPhase.splash => SplashScreen(palette: _theme.palette),
        _BootPhase.ready => AppShell(appState: _appState!, theme: _theme),
        _BootPhase.notConfigured => const FirebaseSetupPrompt(),
        _BootPhase.initFailed =>
          FirebaseInitFailedScreen(onRetry: _retryBoot),
      },
    );
  }
}

/// Logo splash shown the moment the app opens, while Firebase initializes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogoImage(size: 96),
              const SizedBox(height: 20),
              Text(
                'Arxiv',
                style: displayStyle(palette, size: 32)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'a paper library',
                style: bodyStyle(palette, size: 14, color: c.muted),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: palette.accent.accent,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the Firebase config placeholders in
/// `lib/firebase/firebase_config.dart` have not been filled in yet.
class FirebaseSetupPrompt extends StatelessWidget {
  const FirebaseSetupPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    const palette =
        AppPalette(mode: AppMode.dark, accent: AccentPalette.terracotta);
    final c = palette.c;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase not configured',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This app needs a Firebase project before it can load any data.\n\n'
                    '1. Open FIREBASE_SETUP.md in the project root.\n'
                    '2. Follow the console-only steps (no CLI needed).\n'
                    '3. Paste the 7 config values into\n'
                    '    lib/firebase/firebase_config.dart\n'
                    '4. Run: flutter pub get && flutter run',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: c.textSub,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when Firebase is configured but `initializeApp` failed — usually
/// no internet on first launch. Retrying re-runs the whole boot sequence.
class FirebaseInitFailedScreen extends StatelessWidget {
  const FirebaseInitFailedScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const palette =
        AppPalette(mode: AppMode.dark, accent: AccentPalette.terracotta);
    final c = palette.c;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AppLogoImage(size: 64),
                    const SizedBox(height: 20),
                    Text(
                      'Couldn\'t connect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arxiv couldn\'t reach Firebase. Check your internet connection and try again — your papers and account are safe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: c.textSub,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GoldButton(
                      palette: palette,
                      label: 'Try again',
                      minHeight: 48,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
