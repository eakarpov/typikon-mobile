import '../api/report.dart';
import 'session.dart';

/// Бросает [SessionExpiredException], если сессия истекла и продлить её молча
/// не удалось — раньше такой отчёт просто не отправлялся, без единого следа
/// для пользователя.
Future<bool> submitErrorReport({
  required String textId,
  required Map<String, dynamic> selection,
  required String correction,
}) async {
  final response = await withSession(
    () => reportError(
      textId: textId,
      selection: selection,
      correction: correction,
    ),
  );
  return response.statusCode == 200;
}
