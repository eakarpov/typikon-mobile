import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/utils/service_mode.dart';
import 'package:typikon/components/service_reading_scope.dart';
import 'package:typikon/utils/route_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'настройка сохраняется; удержание только при наличии читателя',
    () async {
      final calls = <bool>[];
      final controller = ServiceModeController(
        apply: (v) async {
          calls.add(v);
        },
      );
      await controller.load();
      await controller.setEnabled(true);
      await controller.settled;
      expect(calls, isEmpty);
      final a = Object(), b = Object();
      controller.readerVisible(a, true);
      controller.readerVisible(b, true);
      controller.readerVisible(a, false);
      await controller.settled;
      expect(calls, [true]);
      controller.readerVisible(b, false);
      await controller.settled;
      expect(calls, [true, false]);
      final restored = ServiceModeController(apply: (_) async {});
      await restored.load();
      expect(restored.value, isTrue);
      controller.dispose();
      restored.dispose();
    },
  );

  test('платформенный канал получает включение и выключение', () async {
    const channel = MethodChannel('su.typikon.typikon/utils');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final controller = ServiceModeController();
    controller.readerVisible(Object(), true);
    await controller.setEnabled(true);
    await controller.setEnabled(false);
    await controller.settled;
    expect(calls.map((c) => c.method), ['setKeepScreenOn', 'setKeepScreenOn']);
    expect(calls.map((c) => c.arguments), [true, false]);
    controller.dispose();
  });

  testWidgets('уход с чтения, сворачивание и закрытие снимают удержание', (
    tester,
  ) async {
    final calls = <bool>[];
    final controller = ServiceModeController(
      apply: (v) async {
        calls.add(v);
      },
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [routeObserver],
        home: Scaffold(
          body: ServiceReadingScope(
            controller: controller,
            child: const Center(child: Text('Чтение')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Включить режим «На службе»'));
    await tester.pumpAndSettle();
    await controller.settled;
    expect(calls.last, true);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Меню')),
      ),
    );
    await tester.pumpAndSettle();
    await controller.settled;
    expect(calls.last, false);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await controller.settled;
    expect(calls.last, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await controller.settled;
    expect(calls.last, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await controller.settled;
    expect(calls.last, true);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.settled;
    expect(calls.last, false);
    controller.dispose();
  });
}
