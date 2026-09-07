// Домен сайта записан в приложении один раз — здесь. Переезд правится сменой
// siteHost, а не поиском по файлам: до этой правки адрес стоял в пяти местах
// (базовый адрес API, хост подписного календаря, сверка «свой ли хост» в
// client.dart, подпись в fb2-выгрузке и хост ссылок в AndroidManifest), и одно
// из них ломалось тише прочих — см. ownHosts ниже.
//
// siteHost — как домен пишется в тексте, без протокола и www.
// siteHostFull — имя хоста, на который приложение ходит.
const String siteHost = 'typikon.su';
const String siteHostFull = 'www.$siteHost';

// Домены, которые приложение считает своими и которым представляется заголовком
// appHeaderName. Список, а не один siteHost, из-за переезда на typikon.info:
// пока старый домен отвечает, обе формы наши — выпущенные копии продолжают
// ходить на старую, а обновлённые уже на новую. Старую убирать не раньше, чем
// она перестанет отвечать.
const List<String> ownHosts = <String>['typikon.su', 'typikon.info'];

const String apiBaseUrl = 'https://$siteHostFull';
const String dneslovBaseUrl = 'http://dneslov.org';

const Duration apiTimeout = Duration(seconds: 15);

// Приложение представляется серверу этим заголовком: по нему считается, какая доля
// запросов к устаревшей первой версии API идёт от приложения, а какая от прочих
// клиентов. Пока доля прочих велика, v1 закрывать нельзя.
//
// Версию держим здесь строкой и поднимаем вместе с version в pubspec.yaml.
const String appHeaderName = 'X-Typikon-App';
const String appVersion = '2.0.0+7';

// Подписной календарь чтений на сайте. Хост и путь отдельно — из них же
// собирается webcal://-ссылка, которую календари понимают как подписку.
const String calendarFeedHost = siteHostFull;
const String calendarFeedPath = '/calendar.ics';
const String calendarFeedUrl = 'https://$calendarFeedHost$calendarFeedPath';

// dneslov.org — сторонний сайт, и его доступность нам не подконтрольна: он
// периодически принимает соединение, но не отвечает. Ждать общие 15 секунд в
// таком случае значит держать экран пустым всё это время ради дополнения к
// основному содержимому, поэтому терпение здесь заметно короче.
const Duration dneslovTimeout = Duration(seconds: 6);

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
