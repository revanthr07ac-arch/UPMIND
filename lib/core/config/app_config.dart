import 'dart:io' show File;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Global application configuration and environment-variable loader.
///
/// Supports:
/// 1. Modern publishable browser conventions:
///    - `NEXT_PUBLIC_SUPABASE_URL`
///    - `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
/// 2. Standard / legacy fallbacks:
///    - `SUPABASE_URL`
///    - `SUPABASE_ANON_KEY` / `SUPABASE_PUBLISHABLE_KEY`
/// 3. Compile-time `--dart-define` and `--dart-define-from-file=.env.local`
/// 4. Local file runtime discovery (.env.local, .env) on non-web platforms.
///
/// Security: Server-only secrets (e.g. `SUPABASE_SERVICE_ROLE_KEY`, `GEMINI_API_KEY`)
/// must NEVER be embedded here or sent to the client.
class AppConfig {
  AppConfig._();

  static const String appName = 'UPMIND';
  static const String appTagline =
      'Showcase Skills. Share Knowledge. Grow Together.';

  // Compile-time environment variables (via --dart-define or --dart-define-from-file)
  static const String _compileTimeUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ),
  );

  static const String _compileTimeAnonKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: '',
        ),
      ),
    ),
  );

  // Runtime environment overrides (e.g., loaded from .env.local, .env, or testing)
  static String? _runtimeUrl;
  static String? _runtimeAnonKey;
  static bool _initialized = false;

  /// Initializes configuration from local filesystem files (.env.local, .env)
  /// if compile-time variables were not supplied or are placeholders.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // If compile-time defines are already valid, keep them
    if (_isValidUrl(_compileTimeUrl) && _isValidKey(_compileTimeAnonKey)) {
      return;
    }

    if (!kIsWeb) {
      try {
        final candidates = ['.env.local', '.env'];
        for (final filename in candidates) {
          final file = File(filename);
          if (await file.exists()) {
            final lines = await file.readAsLines();
            final envMap = _parseEnvLines(lines);

            final fileUrl = envMap['NEXT_PUBLIC_SUPABASE_URL'] ??
                envMap['SUPABASE_URL'];
            final fileKey = envMap['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
                envMap['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ??
                envMap['SUPABASE_ANON_KEY'] ??
                envMap['SUPABASE_PUBLISHABLE_KEY'];

            if (_runtimeUrl == null && fileUrl != null && _isValidUrl(fileUrl)) {
              _runtimeUrl = fileUrl.trim();
            }
            if (_runtimeAnonKey == null &&
                fileKey != null &&
                _isValidKey(fileKey)) {
              _runtimeAnonKey = fileKey.trim();
            }
          }
        }
      } catch (e) {
        debugPrint('AppConfig file init error: $e');
      }
    }
  }

  static Map<String, String> _parseEnvLines(List<String> lines) {
    final map = <String, String>{};
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eqIndex = line.indexOf('=');
      if (eqIndex <= 0) continue;
      final key = line.substring(0, eqIndex).trim();
      var value = line.substring(eqIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    return map;
  }

  static bool _isPlaceholder(String val) {
    final v = val.toLowerCase().trim();
    return v.isEmpty ||
        v.contains('xyzcompany') ||
        v.contains('your-project') ||
        v.contains('placeholder') ||
        v.contains('your-anon-key');
  }

  static bool _isValidUrl(String? val) {
    if (val == null || val.isEmpty || _isPlaceholder(val)) return false;
    final uri = Uri.tryParse(val.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static bool _isValidKey(String? val) {
    if (val == null || val.isEmpty || _isPlaceholder(val)) return false;
    return val.trim().length >= 10;
  }

  /// Current active Supabase project URL
  static String get supabaseUrl {
    if (_isValidUrl(_compileTimeUrl)) return _compileTimeUrl.trim();
    if (_isValidUrl(_runtimeUrl)) return _runtimeUrl!.trim();
    return '';
  }

  /// Current active Supabase anonymous / publishable key
  static String get supabaseAnonKey {
    if (_isValidKey(_compileTimeAnonKey)) return _compileTimeAnonKey.trim();
    if (_isValidKey(_runtimeAnonKey)) return _runtimeAnonKey!.trim();
    return '';
  }

  /// Returns true only if both a valid URL and key are provided and are not placeholders
  static bool get isSupabaseConfigured =>
      _isValidUrl(supabaseUrl) && _isValidKey(supabaseAnonKey);

  /// Safe error message describing what is missing, without revealing sensitive information
  static String? get configurationError {
    if (isSupabaseConfigured) return null;
    final hasUrl = _isValidUrl(supabaseUrl);
    final hasKey = _isValidKey(supabaseAnonKey);

    if (!hasUrl && !hasKey) {
      return 'Supabase authentication is not configured. Please supply NEXT_PUBLIC_SUPABASE_URL (or SUPABASE_URL) and NEXT_PUBLIC_SUPABASE_ANON_KEY (or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) in .env.local or via --dart-define.';
    }
    if (!hasUrl) {
      return 'Supabase URL is missing or invalid. Please supply NEXT_PUBLIC_SUPABASE_URL in .env.local or via --dart-define.';
    }
    return 'Supabase anonymous/publishable key is missing or invalid. Please supply NEXT_PUBLIC_SUPABASE_ANON_KEY (or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) in .env.local or via --dart-define.';
  }

  /// Injects credentials programmatically (useful for tests and dynamic setups)
  static void setMockCredentials({String? url, String? anonKey}) {
    _runtimeUrl = url;
    _runtimeAnonKey = anonKey;
    _initialized = true;
  }

  /// Resets credentials (used in teardown of unit tests)
  static void resetCredentials() {
    _runtimeUrl = null;
    _runtimeAnonKey = null;
    _initialized = false;
  }
}
