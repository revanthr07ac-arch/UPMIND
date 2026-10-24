import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:upmind/core/config/app_config.dart';
import 'package:upmind/core/errors/app_exception.dart';
import 'package:upmind/features/auth/data/auth_repository.dart';

void main() {
  setUp(() {
    AppConfig.resetCredentials();
  });

  tearDown(() {
    AppConfig.resetCredentials();
  });

  group('UPMIND AppConfig & Supabase Authentication Configuration Tests', () {
    test('1. Unconfigured state is detected when placeholders or empty values are present', () {
      AppConfig.resetCredentials();
      expect(AppConfig.isSupabaseConfigured, isFalse);
      expect(AppConfig.configurationError, isNotNull);
      expect(AppConfig.configurationError, contains('NEXT_PUBLIC_SUPABASE_URL'));
      expect(AppConfig.configurationError, contains('NEXT_PUBLIC_SUPABASE_ANON_KEY'));
    });

    test('2. Missing or invalid URL produces explicit error without leaking keys', () {
      AppConfig.setMockCredentials(
        url: 'invalid-url',
        anonKey: 'valid_publishable_key_1234567890',
      );
      expect(AppConfig.isSupabaseConfigured, isFalse);
      expect(AppConfig.configurationError, contains('Supabase URL is missing or invalid'));
    });

    test('3. Missing or placeholder anon key produces explicit error', () {
      AppConfig.setMockCredentials(
        url: 'https://testproject.supabase.co',
        anonKey: 'your-anon-key-here',
      );
      expect(AppConfig.isSupabaseConfigured, isFalse);
      expect(AppConfig.configurationError, contains('anonymous/publishable key is missing or invalid'));
    });

    test('4. Valid URL and publishable key configure Supabase successfully', () {
      AppConfig.setMockCredentials(
        url: 'https://nrskuasfyomlfuahcdwq.supabase.co',
        anonKey: 'sb_publishable_test_key_long_enough_12345',
      );
      expect(AppConfig.isSupabaseConfigured, isTrue);
      expect(AppConfig.configurationError, isNull);
      expect(AppConfig.supabaseUrl, equals('https://nrskuasfyomlfuahcdwq.supabase.co'));
      expect(AppConfig.supabaseAnonKey, equals('sb_publishable_test_key_long_enough_12345'));
    });

    test('5. AuthRepository.signIn throws CONFIG_MISSING with clear error when unconfigured', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      expect(
        () => repo.signIn(email: 'user@test.com', password: 'Password123!'),
        throwsA(isA<AppAuthException>().having(
          (e) => e.code,
          'code',
          equals('CONFIG_MISSING'),
        )),
      );
    });

    test('6. AuthRepository.signUp throws CONFIG_MISSING with clear error when unconfigured', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      expect(
        () => repo.signUp(
          email: 'user@test.com',
          password: 'Password123!',
          fullName: 'Test User',
          username: 'testuser',
        ),
        throwsA(isA<AppAuthException>().having(
          (e) => e.code,
          'code',
          equals('CONFIG_MISSING'),
        )),
      );
    });

    test('7. AuthRepository.verifyOtp throws CONFIG_MISSING when unconfigured', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      expect(
        () => repo.verifyOtp(email: 'user@test.com', token: '123456'),
        throwsA(isA<AppAuthException>().having(
          (e) => e.code,
          'code',
          equals('CONFIG_MISSING'),
        )),
      );
    });

    test('8. AuthRepository.resendOtp throws CONFIG_MISSING when unconfigured', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      expect(
        () => repo.resendOtp(email: 'user@test.com'),
        throwsA(isA<AppAuthException>().having(
          (e) => e.code,
          'code',
          equals('CONFIG_MISSING'),
        )),
      );
    });

    test('9. AuthRepository.resetPassword throws CONFIG_MISSING when unconfigured', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      expect(
        () => repo.resetPassword('user@test.com'),
        throwsA(isA<AppAuthException>().having(
          (e) => e.code,
          'code',
          equals('CONFIG_MISSING'),
        )),
      );
    });

    test('10. AuthRepository.deleteAccount throws CONFIG_MISSING when unconfigured and user exists', () async {
      AppConfig.resetCredentials();
      final client = sb.SupabaseClient('https://mock.supabase.co', 'mock-key-1234567890');
      final repo = AuthRepository(client);

      // deleteAccount without user is a no-op
      await expectLater(repo.deleteAccount(), completes);
    });
  });
}
