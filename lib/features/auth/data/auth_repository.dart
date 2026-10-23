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

  Stream<AppAuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final session = data.session;
      if (session != null && session.user != null) {
        return AppAuthState(status: AuthStatus.authenticated, user: session.user);
      }
      return const AppAuthState(status: AuthStatus.unauthenticated);
    });
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return AuthResponse(
          session: null,
          user: User(
            id: 'demo-user-id',
            appMetadata: {},
            userMetadata: {'full_name': fullName, 'username': username},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      }

      final existing = await _supabase
          .from('profiles')
          .select('id')
          .ilike('username', username)
          .maybeSingle();

      if (existing != null) {
        throw const AppAuthException(
          'Username is already taken. Please choose another.',
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
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Registration failed: ${e.toString()}');
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return AuthResponse(
          session: null,
          user: User(
            id: 'demo-user-id',
            appMetadata: {},
            userMetadata: {'full_name': 'Demo User', 'username': 'demouser'},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      }

      return await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on sb.AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
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
      if (AppConfig.isSupabaseConfigured) {
        await _supabase.auth.resetPasswordForEmail(email.trim());
      }
    } on sb.AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Password reset failed: ${e.toString()}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) return;
      if (AppConfig.isSupabaseConfigured) {
        await _supabase.from('profiles').delete().eq('id', user.id);
        await _supabase.auth.signOut();
      }
    } catch (e) {
      throw AppAuthException('Failed to delete account: ${e.toString()}');
    }
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository)
      : super(
          _repository.currentUser != null
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
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
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
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
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

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      final response = await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        username: username,
      );
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: response.user ?? _repository.currentUser,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
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

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }
}
