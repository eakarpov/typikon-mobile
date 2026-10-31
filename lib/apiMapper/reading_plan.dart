import 'dart:convert';
import '../api/reading_plan.dart' as api;
import '../dto/reading_plan.dart';
import 'session.dart';
import 'v2/errors.dart';

Future<PersonalReadingPlan?> getReadingPlan() async {
  final r = await withSession(api.fetchReadingPlan);
  if (r.statusCode != 200) throwV2Error(r, 'Не удалось загрузить личный план');
  final j = jsonDecode(r.body);
  return j == null ? null : PersonalReadingPlan.fromJson(j);
}

Future<PersonalReadingPlan?> updateReadingPlan(
  PersonalReadingPlan plan,
  String action, {
  PlanReminderSettings? reminder,
}) async {
  final r = await withSession(
    () => api.changeReadingPlan({
      'id': plan.id,
      'revision': plan.revision,
      'action': action,
      if (reminder != null) 'reminder': reminder.toJson(),
    }),
  );
  if (r.statusCode != 200) throwV2Error(r, 'Не удалось изменить план');
  final j = jsonDecode(r.body);
  return j == null ? null : PersonalReadingPlan.fromJson(j);
}

Future<PlanNotice?> getPlanNotice(String delivery) async {
  final r = await withSession(() => api.fetchPlanNotice(delivery));
  if (r.statusCode != 200) return null;
  final j = jsonDecode(r.body);
  return j == null ? null : PlanNotice.fromJson(j);
}
