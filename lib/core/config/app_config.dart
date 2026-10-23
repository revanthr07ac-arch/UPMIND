class AppConfig {
  AppConfig._();

  static const String appName = 'UPMIND';
  static const String appTagline =
      'Showcase Skills. Share Knowledge. Grow Together.';

  // Supabase Configuration from Environment or dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xyzcompany.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'public-anon-key-placeholder',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('xyzcompany') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'public-anon-key-placeholder';
}
