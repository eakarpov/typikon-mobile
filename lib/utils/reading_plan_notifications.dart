import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../apiMapper/reading_plan.dart';
import '../dto/reading_plan.dart';
import '../store/auth_token.dart';
import '../store/store.dart';

const readingPlanPushOwnerKey = 'readingPlanPushOwner';
Future<bool> readingPlanPushWanted() async {
  final owner = appStore?.state.auth.userId;
  if (owner == null || appStore?.state.auth.isSignedIn != true) return false;
  return (await SharedPreferences.getInstance()).getString(
        readingPlanPushOwnerKey,
      ) ==
      owner;
}

Future<void> setReadingPlanPushWanted(String owner, bool enabled) async {
  final p = await SharedPreferences.getInstance();
  if (enabled) {
    await p.setString(readingPlanPushOwnerKey, owner);
  } else if (p.getString(readingPlanPushOwnerKey) == owner) {
    await p.remove(readingPlanPushOwnerKey);
  }
}

/// Reject untrusted push arguments. Actual content and active status come from an authenticated fresh request.
String? readingPlanPayloadPlan(String payload, String? owner) {
  final p = payload.split(':');
  return p.length == 3 &&
          p[0] == 'reading-plan' &&
          owner != null &&
          p[1] == owner &&
          RegExp(r'^[a-f0-9-]{36}$').hasMatch(p[2])
      ? p[2]
      : null;
}

String? readingPlanSessionOwner(String? cookie) {
  try {
    final parts = cookie?.split('.');
    if (parts?.length != 3) return null;
    final body = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts![1]))),
    );
    return body is Map && body['userId'] is String
        ? body['userId'] as String
        : null;
  } catch (_) {
    return null;
  }
}

Future<void> checkReadingPlanPush(
  String delivery, {
  required Future<void> Function(PlanNotice) show,
  Future<PlanNotice?> Function(String)? fetchNotice,
}) async {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(delivery) ||
      await getSessionCookie() == null)
    return;
  final cookie = await getSessionCookie();
  final notice = await (fetchNotice ?? getPlanNotice)(delivery);
  if (notice == null || notice.deliveryId != delivery) return;
  final after = await getSessionCookie();
  if (after != cookie &&
      (readingPlanSessionOwner(cookie) != notice.userId ||
          readingPlanSessionOwner(after) != notice.userId))
    return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'readingPlanLastNotice:${notice.userId}';
  if (prefs.getString(key) == delivery) return;
  await prefs.setString(key, delivery);
  await show(notice);
}
