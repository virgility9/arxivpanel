/// Firebase configuration placeholders — manual setup, no Firebase CLI.
///
/// HOW THIS WORKS
/// --------------
/// 1. Follow FIREBASE_SETUP.md (project root) to create your Firebase project
///    and register your Android / iOS / Web apps in the Firebase console.
/// 2. When you register the **Web** app, the console shows a `firebaseConfig`
///    JavaScript object with 7 values. Copy each value into the matching
///    `const` below, replacing the `TODO-...` placeholder.
/// 3. The SAME 7 values work for Android and iOS too (this manual approach
///    replaces the `flutterfire configure` CLI step).
///
/// [DefaultFirebaseConfig.isConfigured] returns false until every placeholder
/// is replaced, in which case the app shows a "Firebase not configured"
/// screen instead of crashing.
library;

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseConfig {
  DefaultFirebaseConfig._();

  // ---------------------------------------------------------------------------
  // Values below were pasted from the Firebase console (web app config).
  // Firebase console → Project settings (gear icon, top-left) → "Your apps"
  // → Web app → "SDK setup and configuration" → Config.
  // ---------------------------------------------------------------------------

  /// Firebase console → Project settings → General → "Your apps" → Web app
  /// → firebaseConfig → `apiKey`.
  static const String apiKey = 'AIzaSyChBfptlZn5yXSEwtzfFtd0CrqWX6zODW8';

  /// Same screen → `appId`.
  static const String appId = '1:415626437581:web:6cefc1935a0b5760d9da84';

  /// Same screen → `messagingSenderId`.
  static const String messagingSenderId = '415626437581';

  /// Same screen → `projectId`.
  static const String projectId = 'arxivpanel-e25a8';

  /// Same screen → `authDomain` (looks like `your-project.firebaseapp.com`).
  static const String authDomain = 'arxivpanel-e25a8.firebaseapp.com';

  /// Same screen → `storageBucket` (looks like `your-project.appspot.com`).
  /// If the console shows a `*.firebasestorage.app` value, either works.
  static const String storageBucket = 'arxivpanel-e25a8.firebasestorage.app';

  /// Same screen → `measurementId` (starts with `G-`). Optional: only used
  /// if you enabled Google Analytics. Leave the placeholder if unused.
  static const String measurementId = 'TODO-PASTE-MEASUREMENT-ID';

  // ---------------------------------------------------------------------------

  /// True once every required placeholder has been replaced with a real value.
  static bool get isConfigured {
    return !apiKey.startsWith('TODO-') &&
        !appId.startsWith('TODO-') &&
        !messagingSenderId.startsWith('TODO-') &&
        !projectId.startsWith('TODO-') &&
        !authDomain.startsWith('TODO-') &&
        !storageBucket.startsWith('TODO-');
    // NOTE: measurementId is optional (Analytics) and not checked.
  }

  /// FirebaseOptions built from the constants above.
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      measurementId: measurementId,
    );
  }
}
