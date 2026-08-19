import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:redux/redux.dart';

import '../api/auth.dart';
import '../api/constants.dart';
import '../store/actions/actions.dart';
import '../store/auth_token.dart';
import '../store/models/models.dart';

Future<void>? _googleSignInInit;

// GoogleSignIn.instance.initialize() должен быть вызван ровно один раз до
// любых других методов — ленивая инициализация при первом реальном
// использовании (вход/выход), без завязки на main.dart.
Future<void> _ensureGoogleSignInInitialized() {
  return _googleSignInInit ??= GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId,
  );
}

Future<String> _deviceId() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return info.id;
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.identifierForVendor ?? 'ios-unknown';
    }
  } catch (_) {}
  return 'unknown-device';
}

String? _extractSessionCookie(String? setCookieHeader) {
  if (setCookieHeader == null) return null;
  final firstCookie = setCookieHeader.split(';').first.trim();
  final eqIndex = firstCookie.indexOf('=');
  if (eqIndex == -1 || !firstCookie.startsWith('session=')) return null;
  return firstCookie.substring(eqIndex + 1);
}

Future<void> signInWithGoogle(Store<AppState> store) async {
  await _ensureGoogleSignInInitialized();
  final account = await GoogleSignIn.instance.authenticate();
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw Exception('Google не вернул токен для входа');
  }

  final response = await loginWithGoogle(
    idToken: idToken,
    expiresIn: 3600,
    userIdHint: account.id,
    deviceId: await _deviceId(),
  );
  if (response.statusCode != 200) {
    throw Exception('Ошибка входа (${response.statusCode})');
  }

  final cookie = _extractSessionCookie(response.headers['set-cookie']);
  if (cookie != null) {
    await saveSessionCookie(cookie);
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  store.dispatch(SignInSuccessAction(
    userId: body['userId'] ?? account.id,
    email: account.email,
    name: account.displayName,
  ));
}

Future<void> signOut(Store<AppState> store) async {
  await _ensureGoogleSignInInitialized();
  try {
    final headers = await authHeader();
    if (headers.isNotEmpty) {
      await logout(headers);
    }
  } catch (_) {
    // Даже если бекенд недоступен — локальный выход должен пройти.
  }
  await GoogleSignIn.instance.signOut();
  await clearSessionCookie();
  store.dispatch(SignOutAction());
}
