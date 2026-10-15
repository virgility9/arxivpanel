# Firebase Setup for ArxivPanel — Console Only (no CLI)

This guide wires the Flutter app to Firebase using **only the Firebase
console** at <https://console.firebase.google.com> plus manual file placement.
You never need the Firebase CLI or `flutterfire configure`.

**Values you will need (exact):**

| Platform | Identifier |
|---|---|
| Android package name | `com.example.arxivpanel` |
| iOS bundle ID | `com.example.arxivpanel` |

> If you later change the applicationId/bundle ID in the Flutter project, you
> must register the new identifiers as new apps in the Firebase console too.

---

## Step 1 — Create the Firebase project

1. Go to <https://console.firebase.google.com> and sign in.
2. Click **Add project** (or "Create a project").
3. Project name: `arxivpanel` (any name works; the ID is auto-generated).
4. When asked about Google Analytics: toggle it **OFF** — the app doesn't use
   Analytics. (You can enable it later; it's optional.)
5. Click **Create project** → **Continue**. You land on the project overview.

## Step 2 — Enable Email/Password authentication

1. In the left sidebar, go to **Build → Authentication**.
2. Click **Get started** (first time only).
3. Open the **Sign-in method** tab.
4. Click **Email/Password** → toggle **Enable** → **Save**.
   (Leave "Email link (passwordless sign-in)" off.)

## Step 3 — Create the Firestore database

1. In the left sidebar, go to **Build → Firestore Database**.
2. Click **Create database**.
3. Choose **Start in production mode** → **Next**.
   (Production mode starts locked down; Step 4 installs the real rules.)
4. Pick the region closest to your users (e.g. `asia-southeast1` for the
   Philippines) → **Enable**. Wait for provisioning to finish.

## Step 4 — Install the Firestore security rules

1. Still in **Build → Firestore Database**, open the **Rules** tab.
2. Delete the default rules text.
3. Open the file `firestore.rules` in this repo, copy its **entire contents**,
   and paste into the Rules editor.
4. Click **Publish**. Wait for "Rules published successfully".

## Step 5 — Firebase Storage (OPTIONAL — skip this)

Firebase Storage is **no longer needed** for this app:

- **Profile pictures** are stored inline in the Firestore user document
  (downscaled data URLs) — works on the free Spark plan.
- **Paper PDFs** are hosted on **Cloudinary's free tier** (see Step 5b) —
  no credit card required.

Only do this step if you ever want Firebase Storage for something else. It
requires the **Blaze (pay-as-you-go)** plan (a card is required, though the
free quotas cover this app's usage):

1. In the Firebase console, click the plan badge at the bottom-left (it says
   **Spark**) → **Upgrade** → set up Cloud Billing.
2. In the left sidebar, go to **Build → Storage**.
3. Click **Get started** → **Next** through the defaults → **Done**.
4. Open the **Rules** tab.
5. Replace the contents with the entire contents of `storage.rules` from this
   repo → **Publish**.

## Step 5b — Cloudinary setup for paper PDFs (free, no card)

Paper PDFs are uploaded to [Cloudinary](https://cloudinary.com)'s free tier
(no credit card required).

1. Sign up at https://cloudinary.com (free plan).
2. On the dashboard, copy your **Cloud name**.
3. Click the gear icon (Settings) → **Upload** tab → scroll to
   **Upload presets** → **Add upload preset**.
4. Set **Signing mode** to **Unsigned** → **Save**. Copy the **Preset name**.
5. Open `lib/data/cloudinary_config.dart` in the repo and paste both values
   into `cloudName` and `uploadPreset`.

Until this is done, submitting a paper with a PDF shows a toast asking for
the Cloudinary setup — the paper itself is still submitted, just without
the PDF attached.

## Step 6 — Register the Android app & add `google-services.json`

1. Click the **gear icon (⚙) → Project settings** (top-left, next to
   "Project Overview").
2. Under **Your apps**, click the **Android** icon (or "Add app" → Android).
3. **Android package name:** `com.example.arxivpanel` — must match exactly.
4. App nickname: `ArxivPanel Android` (optional). **Debug signing certificate
   SHA-1:** leave blank (only needed for Google Sign-In, which this app
   doesn't use).
5. Click **Register app**.
6. Click **Download google-services.json**.
7. Place the file at: **`android/app/google-services.json`** in this repo
   (same folder as `build.gradle.kts`).
8. The Gradle wiring is already in place — verify these two lines exist:
   - `android/settings.gradle.kts` → `id("com.google.gms.google-services") version "4.4.2" apply false`
   - `android/app/build.gradle.kts` → `id("com.google.gms.google-services")`
9. Click through the remaining console steps (**Next → Continue to console**).
   No SDK snippets need to be added — Flutter handles it.

## Step 7 — Register the iOS app & add `GoogleService-Info.plist`

1. **Project settings → Your apps → Add app → iOS.**
2. **Apple bundle ID:** `com.example.arxivpanel` — must match exactly.
3. Click **Register app** → **Download GoogleService-Info.plist**.
4. Add it to the iOS project via Xcode (required — dropping the file in the
   folder is not enough):
   - Open `ios/Runner.xcworkspace` in Xcode.
   - Right-click the **Runner** folder → **Add Files to "Runner"…** →
     select `GoogleService-Info.plist` → ensure **"Copy items if needed"**
     is checked and the **Runner** target is selected → **Add**.
   - Verify: select the file in Xcode → File Inspector → **Target
     Membership → Runner** is checked.
5. Continue through the console steps to the end.

## Step 8 — Register the Web app & fill in `firebase_config.dart`

1. **Project settings → Your apps → Add app → Web** (the `</>` icon).
2. Nickname: `ArxivPanel Web` → **Register app** (skip Firebase Hosting).
3. The console shows **"Add Firebase SDK"** with a `firebaseConfig` object
   containing 7 values. Copy each one into
   **`lib/firebase/firebase_config.dart`**, replacing the `TODO-...`
   placeholders (each constant's comment tells you exactly which field it is):

   | `firebaseConfig` field | Dart constant |
   |---|---|
   | `apiKey` | `apiKey` |
   | `appId` | `appId` |
   | `messagingSenderId` | `messagingSenderId` |
   | `projectId` | `projectId` |
   | `authDomain` | `authDomain` |
   | `storageBucket` | `storageBucket` |
   | `measurementId` | `measurementId` (optional; only if you enabled Analytics) |

   The same 7 values are used for Android and iOS in this manual setup —
   there is nothing else to configure per platform.

## Step 9 — Make yourself an admin

Admin access has **two parts**, both set in the console:

1. **App access** (makes the Admin tab appear): **Build → Firestore
   Database → Data** → open the `users` collection → open the document whose
   ID is your UID → set the `isAdmin` field to `true` (boolean) → **Update**.
   New accounts are created with `isAdmin: false`, and the security rules
   don't allow changing it from inside the app, so this step must be done
   here.
2. **Database permission** (lets approvals, rejections and deletions actually
   save): in **Firestore Database → Data**, open the `admins` collection
   (create it first if it doesn't exist: **Start collection** → Collection ID
   `admins` → **Next**) → **Add document** → Document ID: **paste your UID**
   → add one field, e.g. `role` (string) = `owner` → **Save**. The security
   rules check this collection before allowing any admin write, and the very
   first document must be created here because no admin exists yet to create
   it.

To find a UID: **Build → Authentication → Users** → copy the **User UID**
(it's also the document ID in the `users` collection).

Sign out and back in — the Admin tab appears in the app.

> To add more admins later, repeat both steps with their UIDs.

## Step 10 — Seed content

There's no seed script (no CLI). Two options:

- **Recommended:** open the app, register a second (non-admin) account, use
  **Post Paper** to submit papers, then approve them from the Admin panel
  while signed in as your admin. This exercises the real review flow.
- **Manual:** in **Firestore → Data**, create a `papers` collection and add
  documents with fields matching `Paper.toJson` (`title`, `abstract`,
  `field`, `authorId`, `author`, `coverImage`, `tags` (array), `pages`
  (number), `views` (number), `institution`, `year`, `status` = `approved`,
  `submittedAt` (timestamp), …). Comments go in the `comments` subcollection,
  reactions as one doc per user in the `reactions` subcollection.

## Step 11 — Run the app

```bash
flutter pub get
flutter run
```

- If `lib/firebase/firebase_config.dart` still has placeholders, the app
  opens a **"Firebase not configured"** screen listing these steps instead
  of crashing.
- If Android complains about a missing `google-services.json`, re-check
  Step 6.7 — the file must sit directly in `android/app/`.

---

### Quick reference: where everything lives

| What | Where |
|---|---|
| Firestore rules | `firestore.rules` (repo root) → console: Firestore → Rules |
| Storage rules | `storage.rules` (repo root) → console: Storage → Rules |
| Web config values | `lib/firebase/firebase_config.dart` |
| Android config file | `android/app/google-services.json` (downloaded, not in git) |
| iOS config file | `GoogleService-Info.plist` (added via Xcode, not in git) |
| Data layer | `lib/data/firestore_repository.dart`, `lib/data/auth_repository.dart` |
