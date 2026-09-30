# ArxivPanel — Research Library App (Flutter + Firebase)

A cross-platform research-paper library app: browse papers, read with
reactions and comments, submit your own research for admin review, rank by
community engagement, and manage everything from an admin panel. Dark/light
themes with five accent palettes.

> **⚠️ Required first step:** this app needs a Firebase project before it can
> load any data. Follow **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** — it's a
> console-only guide (no Firebase CLI, ever). Until the config placeholders in
> `lib/firebase/firebase_config.dart` are filled in, the app shows a
> "Firebase not configured" screen instead of crashing.

## Quick start

```bash
flutter pub get
flutter run
```

## Demo flow

1. Complete `FIREBASE_SETUP.md` (create project, enable Email/Password auth,
   create Firestore + Storage, paste the rules, register your apps).
2. Make yourself an admin (setup guide, step 9) — the Admin tab appears after
   you sign back in.
3. Register a second, non-admin account → **Post Paper** → submit a paper.
4. As admin, open the **Admin** tab → approve the paper → it appears in the
   Library for everyone.

## Project structure

```
lib/
  main.dart                  entry point; Firebase init + "not configured" guard
  firebase/
    firebase_config.dart     7 web-config constants (paste from console)
  models/
    models.dart              AppUser, Paper, PaperComment, Poll, … (+ JSON)
  data/
    constants.dart           UI constants (reaction emoji, fields, presets)
    firestore_repository.dart Firestore CRUD + realtime streams
    auth_repository.dart     FirebaseAuth sign-in/sign-up/sign-out
  state/
    app_state.dart           ChangeNotifier: nav, papers, auth, admin actions
  theme/
    app_theme.dart           Material 3 ThemeData (dark/light × 5 accents)
    theme_provider.dart      theme mode state
  widgets/
    app_shell.dart           navbar / bottom nav / routing / toasts
    auth_dialog.dart         email+password sign-in / registration
    paper_card.dart          paper list card
    shared.dart              typography, buttons, chips, formatters
  screens/
    library_screen.dart      paper browser + search/filter
    reader_screen.dart       paper detail, reactions, comments, PDF link
    post_paper_screen.dart   submission form (goes to admin review queue)
    polls_screen.dart        community rankings (Most Reacted/Read/Discussed)
    profile_screen.dart      profile, bookmarks, reading history
    settings_screen.dart     theme + accent + account settings
    admin_screen.dart        review queue: approve / reject / archive
firestore.rules              paste into console: Firestore → Rules
storage.rules                paste into console: Storage → Rules
FIREBASE_SETUP.md            the full console-only setup guide
```

## Backend model (Firestore)

| Collection | Contents |
|---|---|
| `papers` | paper docs, `status`: pending / approved / rejected / revision / archived |
| `papers/{id}/comments` | comment docs |
| `papers/{id}/reactions` | one doc per user (`{uid: {emoji}}`) |
| `users` | profile docs (username = Auth displayName) |
| `users/{uid}/bookmarks` | saved papers |
| `users/{uid}/history` | reading history |
| `polls`, `polls/{id}/options`, `polls/{id}/votes` | polls (one vote per user) |
| `admins` | presence of `admins/{uid}` marks an admin |

Cover images and PDFs are designed for Firebase Storage (`covers/`,
`papers/`); the submission form currently takes cover/PDF **URLs**, so the
bucket and rules are ready for a future file-picker addition.

## Notes

- No Firebase CLI is used anywhere in this project — setup, rules, and config
  are all console + manual file placement.
- `android/app/google-services.json` and iOS `GoogleService-Info.plist` are
  intentionally **not** committed; each developer adds their own (see setup).
- Web fonts from the original design map to built-in serif/monospace/sans.
