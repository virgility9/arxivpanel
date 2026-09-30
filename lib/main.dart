/// Entry point of the ArxivPanel Flutter app (Firebase backend edition).
///
/// Manual Firebase setup (no CLI): [DefaultFirebaseConfig] holds the web-app
/// config values pasted from the Firebase console — see FIREBASE_SETUP.md.
/// If the placeholders haven't been filled in yet, the app shows a friendly
/// "not configured" screen instead of crashing.
///
/// Hand-rolled state wiring (no third-party packages): a [ThemeProvider] and
/// an [AppState] are created once, the root widget rebuilds whenever either
/// notifies, and both are passed down the tree via constructors.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase/firebase_config.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  if (DefaultFirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseConfig.currentPlatform,
      );
      firebaseReady = true;
    } catch (e) {
      // Invalid values, no network, etc. — fall through to the setup screen.
      debugPrint('Firebase.initializeApp failed: $e');
      firebaseReady = false;
    }
  }

  runApp(ArxivPanelApp(firebaseReady: firebaseReady));
}

class ArxivPanelApp extends StatefulWidget {
  const ArxivPanelApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<ArxivPanelApp> createState() => _ArxivPanelAppState();
}

class _ArxivPanelAppState extends State<ArxivPanelApp> {
  late final ThemeProvider _theme = ThemeProvider();
  late final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onChange);
    _appState.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _theme.removeListener(_onChange);
    _appState.removeListener(_onChange);
    _theme.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArxivPanel',
      debugShowCheckedModeBanner: false,
      theme: _theme.themeData,
      home: widget.firebaseReady
          ? AppShell(appState: _appState, theme: _theme)
          : const FirebaseSetupPrompt(),
    );
  }
}

/// Shown when the Firebase config placeholders in
/// `lib/firebase/firebase_config.dart` have not been filled in yet.
class FirebaseSetupPrompt extends StatelessWidget {
  const FirebaseSetupPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    const palette = AppPalette(mode: AppMode.dark, accent: AccentPalette.gold);
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
