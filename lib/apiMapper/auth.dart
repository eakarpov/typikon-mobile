import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:redux/redux.dart';

import '../api/auth.dart';
import '../api/constants.dart';
import '../store/actions/actions.dart';
import '../store/auth_token.dart';
import '../store/pomyannik_cache.dart';
import '../store/models/models.dart';
import '../store/store.dart';

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

Future<bool>? _refreshInFlight;

/// Заводит новую сессию по уже выбранному Google-аккаунту, без диалога входа.
///
/// Сессия на бекенде живёт час (`setExpirationTime('1h')` в
/// typikon-web/src/lib/authorize/sessions.ts), а локальный `isSignedIn` лежит
/// в SharedPreferences бессрочно. Поэтому 401 у "вошедшего" пользователя —
/// штатная ситуация, а не ошибка: пробуем молча получить свежий id_token и
/// обменять его на новую cookie.
///
/// Параллельные 401 (заметки и отчёт об ошибке разом) не должны порождать
/// несколько входов подряд — попытка одна на всех, остальные ждут её.
Future<bool> refreshSessionSilently() {
  return _refreshInFlight ??= _doRefreshSession().whenComplete(() {
    _refreshInFlight = null;
  });
}

Future<bool> _doRefreshSession() async {
  try {
    await _ensureGoogleSignInInitialized();
    // На вебе (FedCM) метод может вернуть null вместо Future — тогда молчаливое
    // продление недоступно и остаётся только обычный вход.
    final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (attempt == null) return false;
    final account = await attempt;
    if (account == null) return false;

    final idToken = account.authentication.idToken;
    if (idToken == null) return false;

    final response = await loginWithGoogle(
      idToken: idToken,
      expiresIn: 3600,
      userIdHint: account.id,
      deviceId: await _deviceId(),
    );
    if (response.statusCode != 200) return false;

    final cookie = _extractSessionCookie(response.headers['set-cookie']);
    if (cookie == null) return false;
    await saveSessionCookie(cookie);
    return true;
  } catch (_) {
    return false;
  }
}

/// Сессии больше нет и восстановить её молча не вышло — гасим локальный вход,
/// чтобы интерфейс не показывал "вы вошли" и пункт "Мои заметки" тому, для
/// кого ни один защищённый запрос уже не проходит.
/// Каждый шаг гасится отдельно: локальный выход обязан состояться, даже если
/// защищённое хранилище или плагин Google по какой-то причине недоступны —
/// иначе интерфейс останется в состоянии "вошёл" навсегда.
Future<void> forgetSession() async {
  try {
    await clearSessionCookie();
  } catch (_) {}
  // Выход СТИРАЕТ помянник с устройства, а не прячет его: в зеркале ближайших
  // дней лежат чужие даты смерти, и держать их после выхода не за что.
  try {
    await clearPomyannikCache();
  } catch (_) {}
  try {
    await _ensureGoogleSignInInitialized();
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
  appStore?.dispatch(SignOutAction());
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
  // Помянник стирается с устройства и здесь, а не только в forgetSession: тот —
  // путь протухшей сессии, а это осознанный выход, и после него имена родни на
  // диске остаться не должны тем более. Обнаружено на устройстве: очистка стояла
  // на одном из двух путей, и по коду это не читалось.
  await clearPomyannikCache();
  store.dispatch(SignOutAction());
}
