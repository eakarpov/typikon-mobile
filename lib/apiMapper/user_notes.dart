import 'dart:convert';

import '../api/user_notes.dart';
import '../dto/user_note.dart';
import 'session.dart';

/// Пустой список раньше возвращался и на 401 тоже — из-за этого истёкшая
/// сессия выглядела как "заметок пока нет", а сохранение молча не работало.
/// Теперь 401 доезжает до страницы как [SessionExpiredException].
Future<List<UserNote>> getUserNotes({String? textId}) async {
  final response = await withSession(() => fetchUserNotes(textId: textId));
  if (response.statusCode != 200) {
    throw Exception('Не удалось загрузить заметки (${response.statusCode})');
  }
  final List<dynamic> data = jsonDecode(response.body);
  return data.map((e) => UserNote.fromJson(e)).toList();
}

Future<String?> submitUserNote({
  required String textId,
  required Map<String, dynamic> selection,
  required String note,
}) async {
  final response = await withSession(
    () => createUserNote(textId: textId, selection: selection, note: note),
  );
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body);
  return data['id'] as String?;
}

Future<bool> editUserNote(String id, String note) async {
  final response = await withSession(() => updateUserNote(id, note));
  return response.statusCode == 200;
}

Future<bool> removeUserNote(String id) async {
  final response = await withSession(() => deleteUserNote(id));
  return response.statusCode == 200;
}
