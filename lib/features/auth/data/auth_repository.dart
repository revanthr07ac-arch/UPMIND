import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(supabase);
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AppAuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final session = data.session;
      final user = session?.user;
      if (session != null && user != null && user.emailConfirmedAt != null) {
        return AppAuthState(status: AuthStatus.authenticated, user: user);
      }
      return const AppAuthState(status: AuthStatus.unauthenticated);
    });
  }

  /// Registers a new user with email and password.
  /// If email confirmation is enabled, returns response with session=null
  /// requiring verifyOtp to complete registration.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured. Please supply NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY (see DEPLOYMENT.md) to enable real OTP email verification.',
          code: 'CONFIG_MISSING',
        );
      }

      // Pre-check for duplicate username
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .ilike('username', username.trim())
          .maybeSingle();

      if (existing != null) {
        throw const AppAuthException(
          'Username is already taken. Please choose another.',
          code: 'USERNAME_TAKEN',
        );
      }

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'username': username.trim().toLowerCase(),
        },
      );

      return response;
    } on AppAuthException {
      rethrow;
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already exists')) {
        throw const AppAuthException(
          'An account with this email already exists. Please sign in.',
          code: 'EMAIL_EXISTS',
        );
      }
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Verifies a 6-digit OTP code sent to user email for signup confirmation.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    sb.OtpType type = sb.OtpType.signup,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured. Real OTP verification requires valid Supabase credentials.',
          code: 'CONFIG_MISSING',
        );
      }

      final response = await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: type,
      );

      if (response.user == null) {
        throw const AppAuthException(
          'Invalid verification code. Please check your email and try again.',
          code: 'INVALID_OTP',
        );
      }

      return response;
    } on AppAuthException {
      rethrow;
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired')) {
        throw const AppAuthException(
          'Verification code has expired. Please request a new code.',
          code: 'OTP_EXPIRED',
        );
      }
      if (msg.contains('invalid') ||
          msg.contains('token') ||
          msg.contains('otp')) {
        throw const AppAuthException(
          'Invalid verification code. Please check your email and enter the 6-digit code.',
          code: 'INVALID_OTP',
        );
      }
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Verification failed: ${e.toString()}');
    }
  }

  /// Resends the signup OTP verification code to the specified email.
  Future<void> resendOtp({
    required String email,
    sb.OtpType type = sb.OtpType.signup,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured. Real OTP delivery requires valid Supabase credentials.',
          code: 'CONFIG_MISSING',
        );
      }

      await _supabase.auth.resend(
        email: email.trim(),
        type: type,
      );
    } on AppAuthException {
      rethrow;
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') ||
          e.statusCode == '429' ||
          msg.contains('security purposes') ||
          msg.contains('seconds')) {
        throw const AppAuthException(
          'Please wait a minute before requesting another verification code.',
          code: 'RATE_LIMIT',
        );
      }
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Failed to resend code: ${e.toString()}');
    }
  }

  /// Authenticates using email and password against Supabase Auth.
  /// Throws AppAuthException if credentials are invalid or if email is unverified.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured. Please supply NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to sign in.',
          code: 'CONFIG_MISSING',
        );
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user != null && user.emailConfirmedAt == null) {
        throw const AppAuthException(
          'Your email address is not verified yet. Please enter the verification code sent to your email.',
          code: 'EMAIL_NOT_CONFIRMED',
        );
      }

      return response;
    } on sb.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('email not confirmed') ||
          e.code == 'email_not_confirmed') {
        throw const AppAuthException(
          'Your email address is not verified yet. Please enter the verification code sent to your email.',
          code: 'EMAIL_NOT_CONFIRMED',
        );
      }
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        throw const AppAuthException(
          'Invalid email or password. Please check your credentials.',
          code: 'INVALID_CREDENTIALS',
        );
      }
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Sign in failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        await _supabase.auth.signOut();
      }
    } catch (e) {
      throw AppAuthException('Sign out failed: ${e.toString()}');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured. Please supply NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to reset password.',
          code: 'CONFIG_MISSING',
        );
      }
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Password reset failed: ${e.toString()}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) return;
      if (!AppConfig.isSupabaseConfigured) {
        throw AppAuthException(
          AppConfig.configurationError ??
              'Supabase authentication is not configured.',
          code: 'CONFIG_MISSING',
        );
      }
      await _supabase.from('profiles').delete().eq('id', user.id);
      await _supabase.auth.signOut();
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to delete account: ${e.toString()}');
    }
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository)
      : super(
          _repository.currentUser != null &&
                  _repository.currentUser!.emailConfirmedAt != null
              ? AppAuthState(
                  status: AuthStatus.authenticated,
                  user: _repository.currentUser,
                )
              : const AppAuthState(status: AuthStatus.unauthenticated),
        ) {
    if (AppConfig.isSupabaseConfigured) {
      _repository.authStateChanges.listen((newState) {
        state = newState;
      });
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );
    try {
      final response = await _repository.signIn(
        email: email,
        password: password,
      );
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: response.user ?? _repository.currentUser,
      );
      return true;
    } on AppAuthException catch (e) {
      if (e.code == 'EMAIL_NOT_CONFIRMED') {
        state = state.copyWith(
          status: AuthStatus.unverified,
          unverifiedEmail: email.trim(),
          errorMessage: e.message,
          errorCode: e.code,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.message,
          errorCode: e.code,
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );
    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        username: username,
      );
      // Signup was registered with provider; transition to unverified awaiting OTP
      state = state.copyWith(
        status: AuthStatus.unverified,
        unverifiedEmail: email.trim(),
        clearError: true,
      );
      return true;
    } on AppAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
        errorCode: e.code,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );
    try {
      final response = await _repository.verifyOtp(
        email: email,
        token: token,
      );
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: response.user ?? _repository.currentUser,
      );
      return true;
    } on AppAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unverified,
        unverifiedEmail: email.trim(),
        errorMessage: e.message,
        errorCode: e.code,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unverified,
        unverifiedEmail: email.trim(),
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> resendOtp({required String email}) async {
    try {
      await _repository.resendOtp(email: email);
      return true;
    } on AppAuthException catch (e) {
      state = state.copyWith(
        errorMessage: e.message,
        errorCode: e.code,
      );
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  void setUnverifiedEmail(String email) {
    state = state.copyWith(
      status: AuthStatus.unverified,
      unverifiedEmail: email.trim(),
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }
}
