import 'package:meta/meta.dart';

@immutable
class AuthState {
  final bool isSignedIn;
  final String? userId;
  final String? email;
  final String? name;

  const AuthState({
    this.isSignedIn = false,
    this.userId,
    this.email,
    this.name,
  });

  factory AuthState.init() => const AuthState();

  @override
  int get hashCode =>
      isSignedIn.hashCode ^ userId.hashCode ^ email.hashCode ^ name.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AuthState &&
              isSignedIn == other.isSignedIn &&
              userId == other.userId &&
              email == other.email &&
              name == other.name;

  @override
  String toString() {
    return 'AuthState{isSignedIn: $isSignedIn, userId: $userId, email: $email, name: $name}';
  }

  Map<String, dynamic> toJson() {
    return {
      'isSignedIn': isSignedIn,
      'userId': userId,
      'email': email,
      'name': name,
    };
  }

  static AuthState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AuthState();
    return AuthState(
      isSignedIn: json['isSignedIn'] ?? false,
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
    );
  }
}
