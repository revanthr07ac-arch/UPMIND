import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus { initial, unauthenticated, authenticating, authenticated }

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.authenticating;

  AppAuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}
