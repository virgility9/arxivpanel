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

  static const List<String> presetCovers = [
    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=400&h=600&fit=crop&auto=format',
    'https://images.unsplash.com/photo-1532619675605-1ede6c2ed2b0?w=400&h=600&fit=crop&auto=format',
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=400&h=600&fit=crop&auto=format',
    'https://images.unsplash.com/photo-1509228627152-72ae9ae6848d?w=400&h=600&fit=crop&auto=format',
    'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=400&h=600&fit=crop&auto=format',
    'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&h=600&fit=crop&auto=format',
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
