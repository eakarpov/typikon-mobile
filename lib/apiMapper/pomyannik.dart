import 'dart:convert';

import '../api/pomyannik.dart' as api;
import '../dto/paged.dart';
import '../dto/pomyannik.dart';
import 'session.dart';
import 'v2/errors.dart';

/// Разбор помянника.
///
/// Всякий личный вызов идёт через [withSession]: сессия сайта живёт час, и
/// протухает она не по вине пользователя, а по устройству веба. `withSession`
/// молча её обновляет и повторяет запрос, а если не вышло — бросает
/// [SessionExpiredException], и страница просит войти.
///
/// Отказы разбираются общим `throwV2Error`. Личных кодов два, и оба доходят до
/// экрана словами сервера: `session_required` («нужен вход») и `conflict`
/// («в помяннике не больше пятисот имён»).

/// Словарь чинов и видов поминовения.
///
/// **Без запасной таблицы в коде.** Церковнославянских начертаний у пяти помет
/// нет вовсе, и `null` там значит «книгой не подтверждено». Своя копия — это
/// второе место, где кто-нибудь заполнит пробел, и тогда в записке будет
/// напечатано выдуманное за книгу. Пока словарь не пришёл, чин не подписан — и
/// это верно: лучше без чина, чем с неверным.
Future<Vocabulary> getVocabulary() async {
  final response = await api.fetchVocabulary();
  if (response.statusCode == 200) {
    return Vocabulary.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить словари помянника");
}

Future<List<MemorialDay>> getMemorialDays(int year) async {
  final response = await api.fetchMemorialDays(year);
  if (response.statusCode == 200) {
    final days = jsonDecode(response.body)["days"];
    return days is List ? days.map((e) => MemorialDay.fromJson(e)).toList() : <MemorialDay>[];
  }
  throwV2Error(response, "Не удалось загрузить поминальные дни");
}

/// Что мы знаем об имени.
///
/// Отказ наружу не бросаем: сверка — подспорье при записи, а не условие её.
/// Не ответил сервер — запишем как ввели, без подсказки.
Future<NameCheck?> getNameCheck(String query) async {
  try {
    final response = await withSession(() => api.fetchNameCheck(query));
    if (response.statusCode != 200) return null;
    return NameCheck.fromJson(jsonDecode(response.body));
  } catch (_) {
    return null;
  }
}

Future<Paged<Person>> getPersons({String? kind, int offset = 0}) async {
  final response = await withSession(() => api.fetchPersons(kind: kind, offset: offset));
  if (response.statusCode == 200) {
    return Paged.fromJson<Person>(jsonDecode(response.body), Person.fromJson);
  }
  throwV2Error(response, "Не удалось открыть помянник");
}

Future<PersonCard> getPerson(String id) async {
  final response = await withSession(() => api.fetchPerson(id));
  if (response.statusCode == 200) {
    return PersonCard.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось открыть запись");
}

/// Записать имена.
///
/// Ответ отдаём целиком: сервер дописывает к присланному то, чего мы не знаем, —
/// ключ имени, пол по имени и именины по указателю святцев, — и показывать надо
/// записанное, а не отправленное.
Future<List<Person>> addPersons(List<Map<String, dynamic>> persons) async {
  final response = await withSession(() => api.createPersons(persons));
  if (response.statusCode == 201) {
    final items = jsonDecode(response.body)["items"];
    return items is List ? items.map((e) => Person.fromJson(e)).toList() : <Person>[];
  }
  throwV2Error(response, "Не удалось записать имя");
}

Future<Person> savePerson(Person person) async {
  final response = await withSession(() => api.savePerson(person.id, person.toInput()));
  if (response.statusCode == 200) {
    return Person.fromJson(jsonDecode(response.body)["person"] ?? const {});
  }
  throwV2Error(response, "Не удалось поправить запись");
}

Future<void> removePerson(String id) async {
  final response = await withSession(() => api.removePerson(id));
  if (response.statusCode == 200) return;
  throwV2Error(response, "Не удалось убрать запись");
}

Future<Upcoming> getUpcoming({required String from, int days = 60}) async {
  final response = await withSession(() => api.fetchUpcoming(from: from, days: days));
  if (response.statusCode == 200) {
    return Upcoming.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось посчитать ближайшие дни");
}

// --- Записка ------------------------------------------------------------------

/// Лист записки до подачи.
///
/// Считает его сервер, и не от лени: церковнославянский родительный падеж стоит
/// на словаре личных имён и склонении по схеме, а ни того ни другого на
/// телефоне нет. Отказ проверки («панихида — заупокойное поминовение, живых в
/// него не вписывают: Николай») приходит оттуда же и показывается как есть.
Future<NoteSheet> getNoteSheet(String kind, List<String> personIds) async {
  final response = await withSession(() => api.fetchNoteSheet(kind, personIds));
  if (response.statusCode == 200) {
    return NoteSheet.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось собрать записку");
}

Future<Zapiska> sendNote(
  String kind,
  List<String> personIds, {
  String? code,
  String? slug,
}) async {
  final response =
      await withSession(() => api.sendNote(kind, personIds, code: code, slug: slug));
  if (response.statusCode == 201) {
    return Zapiska.fromJson(jsonDecode(response.body)["note"] ?? const {});
  }
  throwV2Error(response, "Не удалось подать записку");
}

Future<Paged<Zapiska>> getSentNotes({int offset = 0}) async {
  final response = await withSession(() => api.fetchSentNotes(offset: offset));
  if (response.statusCode == 200) {
    return Paged.fromJson<Zapiska>(jsonDecode(response.body), Zapiska.fromJson);
  }
  throwV2Error(response, "Не удалось открыть поданные записки");
}

// --- Приём --------------------------------------------------------------------

/// Поданные священнику записки.
///
/// Приём не открыт — сервер отвечает `403`, и это доходит до экрана как
/// [ApiUnauthorizedException] с его же словами. Пустым списком подменять нельзя:
/// пустой значил бы «вам никто не подавал», а правды в этом нет.
Future<Prinyatye> getReceivedNotes({int offset = 0}) async {
  final response = await withSession(() => api.fetchReceivedNotes(offset: offset));
  if (response.statusCode == 200) {
    return Prinyatye.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось открыть поданные записки");
}

Future<void> markNote(String id, String mark) async {
  final response = await withSession(() => api.markNote(id, mark));
  if (response.statusCode == 200) return;
  throwV2Error(response, "Не удалось отметить записку");
}

// --- Устройства ---------------------------------------------------------------

/// Сказать серверу, куда стучаться.
///
/// Возвращает `false` вместо броска: привязка устройства — не то, ради чего
/// стоит показывать окно с ошибкой. Не вышло — напоминания просто останутся за
/// приложением, а следующий запуск попробует снова.
Future<bool> registerDevice(String token, String timeZone, {int? readingHour}) async {
  try {
    final response = await withSession(
        () => api.registerDevice(token, timeZone, readingHour: readingHour));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Отвязать устройство: выключили толчки или вышли из учётной записи.
///
/// Тоже молча. Хуже всего было бы помешать выходу из учётной записи из-за
/// неудавшегося сетевого запроса.
Future<bool> forgetDevice(String token) async {
  try {
    final response = await withSession(() => api.forgetDevice(token));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
