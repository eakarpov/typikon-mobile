import '../api/report.dart';

Future<bool> submitErrorReport({
  required String textId,
  required Map<String, dynamic> selection,
  required String correction,
}) async {
  final response = await reportError(
    textId: textId,
    selection: selection,
    correction: correction,
  );
  return response.statusCode == 200;
}
