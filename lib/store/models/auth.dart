import 'package:flutter/foundation.dart';

@immutable
class AuthState {
  final bool isSignedIn;
  final String? userId;
  final String? email;
  final String? name;

  /// Открыт ли этому человеку приём записок — то есть подтверждён ли он в
  /// личном кабинете на сайте.
  ///
  /// Отдельной ручки, чтобы это спросить, у сервера нет: единственный признак —
  /// как он отвечает на сам раздел, `200` или `403`. Поэтому ответ спрашивается
  /// раз и запоминается здесь, а `AuthState` и так уезжает на диск и очищается
  /// при выходе — ровно то, что этому признаку нужно.
  ///
  /// **По умолчанию `false`, и это нарочно.** Не спросив, раздел не показываем:
  /// заглушка «приём вам не открыт» в меню у всех подряд — это обещание
  /// возможности, которой у человека нет.
  final bool isCommemorator;

  const AuthState({
    this.isSignedIn = false,
    this.userId,
    this.email,
    this.name,
    this.isCommemorator = false,
  });

  factory AuthState.init() => const AuthState();

  @override
  int get hashCode =>
      isSignedIn.hashCode ^
      userId.hashCode ^
      email.hashCode ^
      name.hashCode ^
      isCommemorator.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AuthState &&
              isSignedIn == other.isSignedIn &&
              userId == other.userId &&
              email == other.email &&
              name == other.name &&
              isCommemorator == other.isCommemorator;

  @override
  String toString() {
    return 'AuthState{isSignedIn: $isSignedIn, userId: $userId, email: $email, '
        'name: $name, isCommemorator: $isCommemorator}';
  }

  Map<String, dynamic> toJson() {
    return {
      'isSignedIn': isSignedIn,
      'userId': userId,
      'email': email,
      'name': name,
      'isCommemorator': isCommemorator,
    };
  }

  AuthState copyWith({bool? isCommemorator}) => AuthState(
        isSignedIn: isSignedIn,
        userId: userId,
        email: email,
        name: name,
        isCommemorator: isCommemorator ?? this.isCommemorator,
      );

  static AuthState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AuthState();
    return AuthState(
      isSignedIn: json['isSignedIn'] ?? false,
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
      isCommemorator: json['isCommemorator'] ?? false,
    );
  }
}
