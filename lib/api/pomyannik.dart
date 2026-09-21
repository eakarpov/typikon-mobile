import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Помянник: имена и дни, которые они приносят.
///
/// **Личное не кэшируется.** `cachedFetch` пишет на диск в общий кэш-каталог,
/// который чистит и система, и кнопка «сбросить кэш» в настройках; класть туда
/// имена родни незачем и негде. Кэшируются только два общих ответа — словарь
/// чинов и поминальные субботы, — в них ни о ком ничего не сказано.
///
/// Личные запросы идут через [v2Send], а не [v2Get]: тому нужна сессия, и он
/// никогда не объявляет ключ негодным по чужой вине.

const int pomyannikPageSize = 200;

// --- Общее --------------------------------------------------------------------

/// Чины и виды поминовения. Меняются правкой в исходниках сервера, то есть
/// выпуском, — держим долго.
Future<http.Response> fetchVocabulary() {
  return cachedFetch(
    "pomyannik:vocabulary",
    () => v2Get(v2Uri("/pomyannik/vocabulary")),
    ttl: const Duration(days: 30),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["ranks"] is List;
    },
  );
}

/// Поминальные дни года. Считаются от Пасхи и внутри года неизменны, поэтому
/// год входит и в запрос, и в ключ: без него ответ прошлого года был бы неверен
/// молча.
Future<http.Response> fetchMemorialDays(int year) {
  return cachedFetch(
    "pomyannik:calendar:$year",
    () => v2Get(v2Uri("/pomyannik/calendar", {"year": "$year"})),
    ttl: const Duration(days: 60),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["days"] is List;
    },
  );
}

/// Сверка имени до записи. Не кэшируем: спрашивают её один раз на имя.
Future<http.Response> fetchNameCheck(String query) =>
    v2Send("GET", v2Uri("/pomyannik/name", {"q": query}));

// --- Лица ---------------------------------------------------------------------

Future<http.Response> fetchPersons({String? kind, int offset = 0}) {
  return v2Send("GET", v2Uri("/pomyannik/persons", {
    "limit": "$pomyannikPageSize",
    if (offset > 0) "offset": "$offset",
    "kind": ?kind,
  }));
}

Future<http.Response> fetchPerson(String id) =>
    v2Send("GET", v2Uri("/pomyannik/persons/$id"));

Future<http.Response> createPersons(List<Map<String, dynamic>> persons) =>
    v2Send("POST", v2Uri("/pomyannik/persons"),
        body: persons.length == 1 ? persons.single : {"persons": persons});

/// Правка уходит лицом целиком — см. `Person.toInput`.
Future<http.Response> savePerson(String id, Map<String, dynamic> person) =>
    v2Send("PUT", v2Uri("/pomyannik/persons/$id"), body: person);

Future<http.Response> removePerson(String id) =>
    v2Send("DELETE", v2Uri("/pomyannik/persons/$id"));

/// Ближайшие дни.
///
/// [from] отправляем всегда и своё, местное: часовой пояс телефона свой, и в
/// час пополуночи серверное «сегодня» бывает вчерашним.
Future<http.Response> fetchUpcoming({required String from, int days = 60}) =>
    v2Send("GET", v2Uri("/pomyannik/upcoming", {"from": from, "days": "$days"}));

// --- Записка ------------------------------------------------------------------

Future<http.Response> fetchNoteSheet(String kind, List<String> personIds) =>
    v2Send("POST", v2Uri("/pomyannik/note/preview"),
        body: {"kind": kind, "personIds": personIds});

Future<http.Response> sendNote(
  String kind,
  List<String> personIds, {
  String? code,
  String? slug,
}) =>
    v2Send("POST", v2Uri("/pomyannik/zapiski"), body: {
      "kind": kind,
      "personIds": personIds,
      if (code != null && code.isNotEmpty) "code": code,
      if (slug != null && slug.isNotEmpty) "slug": slug,
    });

Future<http.Response> fetchSentNotes({int offset = 0}) =>
    v2Send("GET", v2Uri("/pomyannik/zapiski", {
      "limit": "$pomyannikPageSize",
      if (offset > 0) "offset": "$offset",
    }));

// --- Приём --------------------------------------------------------------------

Future<http.Response> fetchReceivedNotes({int offset = 0}) =>
    v2Send("GET", v2Uri("/pomyannik/prinyatye", {
      "limit": "$pomyannikPageSize",
      if (offset > 0) "offset": "$offset",
    }));

Future<http.Response> markNote(String id, String mark) =>
    v2Send("PATCH", v2Uri("/pomyannik/prinyatye/$id"), body: {"mark": mark});

// --- Устройства ---------------------------------------------------------------

/// Запомнить устройство, чтобы пуш о поминальном дне приходил в минуту.
///
/// Часовой пояс обязателен: сервер считает утро по месту телефона, а не по
/// своему. Восемь утра в Петропавловске и восемь утра в Калининграде —
/// одиннадцать часов разницы.
Future<http.Response> registerDevice(String token, String timeZone, {int? readingHour}) =>
    v2Send("POST", v2Uri("/pomyannik/devices"), body: {
      "token": token,
      "timeZone": timeZone,
      "platform": "android",
      // Час чтений дня. Не выбран — поле уходит `null`, и сервер о чтениях
      // этому устройству не пишет: молчание тут и есть выбор.
      "readingHour": readingHour,
    });

Future<http.Response> forgetDevice(String token) =>
    v2Send("DELETE", v2Uri("/pomyannik/devices", {"token": token}));
