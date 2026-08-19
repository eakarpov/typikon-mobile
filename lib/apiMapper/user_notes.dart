import 'dart:convert';

import '../api/user_notes.dart';
import '../dto/user_note.dart';

Future<List<UserNote>> getUserNotes({String? textId}) async {
  final response = await fetchUserNotes(textId: textId);
  if (response.statusCode != 200) return [];
  final List<dynamic> data = jsonDecode(response.body);
  return data.map((e) => UserNote.fromJson(e)).toList();
}

Future<String?> submitUserNote({
  required String textId,
  required Map<String, dynamic> selection,
  required String note,
}) async {
  final response = await createUserNote(textId: textId, selection: selection, note: note);
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body);
  return data['id'] as String?;
}

Future<bool> editUserNote(String id, String note) async {
  final response = await updateUserNote(id, note);
  return response.statusCode == 200;
}

Future<bool> removeUserNote(String id) async {
  final response = await deleteUserNote(id);
  return response.statusCode == 200;
}
