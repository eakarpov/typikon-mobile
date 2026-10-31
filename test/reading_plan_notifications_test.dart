import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/utils/reading_plan_notifications.dart';
import 'package:typikon/dto/reading_plan.dart';
import 'package:typikon/store/auth_token.dart';

void main() {
  const owner = '65f0c1e2a3b4c5d6e7f80910',
      plan = '12345678-1234-1234-1234-123456789abc';
  final delivery = 'a' * 64;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    readSessionCookie = () async => 'test-cookie';
  });
  tearDown(resetSessionCookieSource);
  test('tap is bound to the signed-in owner and rejects arbitrary routes', () {
    expect(readingPlanPayloadPlan('reading-plan:$owner:$plan', owner), plan);
    expect(
      readingPlanPayloadPlan('reading-plan:$owner:$plan', 'other'),
      isNull,
    );
    expect(readingPlanPayloadPlan('https://evil.test', owner), isNull);
  });
  test('paused/deleted/stale notice (null response) never displays', () async {
    var shown = 0;
    await checkReadingPlanPush(
      delivery,
      fetchNotice: (_) async => null,
      show: (_) async {
        shown++;
      },
    );
    expect(shown, 0);
  });
  test('delivery is displayed once and links to current plan', () async {
    var shown = 0;
    final notice = PlanNotice.fromJson({
      'userId': owner,
      'planId': plan,
      'deliveryId': delivery,
      'body': 'Статия 2',
    });
    for (var i = 0; i < 2; i++) {
      await checkReadingPlanPush(
        delivery,
        fetchNotice: (_) async => notice,
        show: (n) async {
          shown++;
          expect(n.payload, 'reading-plan:$owner:$plan');
        },
      );
    }
    expect(shown, 1);
  });
  test(
    'a session change while fetching suppresses old account notification',
    () async {
      var shown = 0;
      await checkReadingPlanPush(
        delivery,
        fetchNotice: (_) async {
          readSessionCookie = () async => 'new-cookie';
          return PlanNotice.fromJson({
            'userId': owner,
            'planId': plan,
            'deliveryId': delivery,
            'body': 'Text',
          });
        },
        show: (_) async {
          shown++;
        },
      );
      expect(shown, 0);
    },
  );
  test(
    'silent session refresh for the same owner does not discard a valid reminder',
    () async {
      String cookie(String id, String suffix) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'userId': id}))).replaceAll('=', '')}.$suffix';
      readSessionCookie = () async => cookie(owner, 'old');
      var shown = 0;
      await checkReadingPlanPush(
        delivery,
        fetchNotice: (_) async {
          readSessionCookie = () async => cookie(owner, 'new');
          return PlanNotice.fromJson({
            'userId': owner,
            'planId': plan,
            'deliveryId': delivery,
            'body': 'Text',
          });
        },
        show: (_) async {
          shown++;
        },
      );
      expect(shown, 1);
    },
  );
}
