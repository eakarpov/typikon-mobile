const String apiBaseUrl = 'https://www.typikon.su';
const String dneslovBaseUrl = 'http://dneslov.org';

const Duration apiTimeout = Duration(seconds: 15);

// Тот же Google OAuth web client id, что бекенд читает из GOOGLE_APP и
// проверяет как audience при верификации id_token (не секрет, публичный
// идентификатор). Передаётся в GoogleSignIn как serverClientId, чтобы
// на Android/iOS id_token приходил с этой же audience.
//
// Сам по себе этот client id НЕ включает мобильные платформы — чтобы
// диалог входа заработал на устройстве, нужно ещё зарегистрировать
// отдельные Android (package su.typikon.typikon + SHA-1) и iOS
// (bundle id su.typikon.typikon) OAuth-клиенты в том же проекте Google
// Cloud Console. Без этого шага signInWithGoogle() будет падать с
// ошибкой конфигурации, даже если код собран корректно.
const String googleServerClientId =
    '632612414346-v35c46qfr6sl39glq93r6g6m6cqkpolq.apps.googleusercontent.com';
