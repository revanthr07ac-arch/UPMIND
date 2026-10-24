import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  unverified,
  authenticated,
}

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final String? unverifiedEmail;
  final String? errorMessage;
  final String? errorCode;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.unverifiedEmail,
    this.errorMessage,
    this.errorCode,
  });

  /// Strict authentication check: Must have status authenticated,
  /// a valid user object, and confirmed email timestamp.
  bool get isAuthenticated =>
      status == AuthStatus.authenticated &&
      user != null &&
      user!.emailConfirmedAt != null;

  bool get isLoading => status == AuthStatus.authenticating;
  bool get isUnverified => status == AuthStatus.unverified;

  AppAuthState copyWith({
    AuthStatus? status,
    User? user,
    String? unverifiedEmail,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      unverifiedEmail: unverifiedEmail ?? this.unverifiedEmail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
