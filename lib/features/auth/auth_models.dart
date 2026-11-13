/// Authenticated learner profile returned by `/api/auth/sign-in` and `/api/auth/me`.
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.emailVerified,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'learner',
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  final int userId;
  final String email;
  final String fullName;
  final String role;
  final bool emailVerified;
}

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Current authentication state of the mobile client.
class AuthState {
  const AuthState._({
    required this.status,
    this.user,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AuthUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
}
