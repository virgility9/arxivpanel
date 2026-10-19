/// Cloudinary configuration for paper PDF uploads.
///
/// Cloudinary's free tier needs no credit card, which makes it the upload
/// host for users without Blaze billing.
///
/// HOW THIS WORKS
/// --------------
/// 1. Sign up at https://cloudinary.com (free, no card required).
/// 2. On the dashboard, copy your **Cloud name**.
/// 3. Settings (gear icon) → Upload → Upload presets → Add upload preset →
///    set Signing mode to **Unsigned** → Save → copy the **Preset name**.
/// 4. Paste both values into the `const`s below.
library;

class CloudinaryConfig {
  CloudinaryConfig._();

  static const cloudName = 'vo35jey5';
  static const uploadPreset = 'dqewyf6q';

  static bool get isConfigured =>
      !cloudName.startsWith('YOUR_') && !uploadPreset.startsWith('YOUR_');
}
