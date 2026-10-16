/// UI constants shared across the app.
///
/// These are UI constants (emoji palette, research fields, cover/avatar
/// image pools), not mock data, so they live in a dedicated constants file
/// rather than with any dataset.
library;

class AppConstants {
  AppConstants._();

  static const List<String> reactions = ['🔥', '🧠', '👏', '❤️', '✨', '🌱'];

  static const List<String> fields = [
    'All Fields',
    'Machine Learning',
    'Astrophysics',
    'Molecular Biology',
    'Cryptography',
    'Psychology',
    'Urban Planning',
    'Mathematics',
    'Physics',
    'Economics',
    'Electrical Engineering',
  ];

  /// Cartoonish preset avatars (DiceBear, PNG). Shown in the Edit Profile
  /// dialog and assigned to new signups.
  static const List<String> randomAvatars = [
    'https://api.dicebear.com/9.x/adventurer/png?seed=Felix&size=128',
    'https://api.dicebear.com/9.x/big-smile/png?seed=Luna&size=128',
    'https://api.dicebear.com/9.x/croodles/png?seed=Max&size=128',
    'https://api.dicebear.com/9.x/lorelei/png?seed=Nova&size=128',
    'https://api.dicebear.com/9.x/micah/png?seed=Sunny&size=128',
    'https://api.dicebear.com/9.x/personas/png?seed=Zoe&size=128',
  ];
}
