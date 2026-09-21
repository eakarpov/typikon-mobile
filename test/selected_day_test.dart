import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/utils/selected_day.dart';

/// Общий выбранный день трёх экранов.
///
/// До примеси у каждого была своя копия: окно выбора трижды, сверка «тот же ли
/// это день» — дважды и по-разному, а переход через полночь знала одна главная.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with WidgetsBindingObserver, SelectedDay {
  /// Дни, на которые страницу просили загрузиться, по порядку.
  final List<String> loaded = [];

  @override
  void loadDay(DateTime day) => loaded.add(SelectedDay.keyOf(day));

  @override
  Widget build(BuildContext context) => Text(
        SelectedDay.keyOf(selectedDay),
        textDirection: TextDirection.ltr,
      );
}

void main() {
  Future<(Store<AppState>, _ProbeState)> pumpProbe(WidgetTester tester) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: const MaterialApp(home: _Probe()),
    ));
    return (store, tester.state<_ProbeState>(find.byType(_Probe)));
  }

  testWidgets("день грузится один раз, а не на каждый возврат", (tester) async {
    // didChangeDependencies зовётся на каждый экран, положенный поверх и
    // снятый: без сверки возврат из текста стоил бы запроса и потерянного
    // места в списке.
    final (_, probe) = await pumpProbe(tester);
    expect(probe.loaded.length, 1);

    probe.didChangeDependencies();
    probe.didChangeDependencies();

    expect(probe.loaded.length, 1);
  });

  testWidgets("переход на другой день перезагружает и запоминается в сторе",
      (tester) async {
    final (store, probe) = await pumpProbe(tester);
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    probe.goToDay(tomorrow);
    await tester.pump();

    expect(probe.loaded.last, SelectedDay.keyOf(tomorrow));
    expect(SelectedDay.keyOf(store.state.common.date), SelectedDay.keyOf(tomorrow));
    // День виден и на экране — прежде он показывался лишь потому, что закрытие
    // окна выбора случайно дёргало didChangeDependencies.
    expect(find.text(SelectedDay.keyOf(tomorrow)), findsOneWidget);
  });

  testWidgets("выбранный день един для экранов", (tester) async {
    // Смысл общего дня: сменили на одном экране — второй откроется на нём же.
    final (store, probe) = await pumpProbe(tester);
    final feast = DateTime(2027, 1, 7);

    store.dispatch(ChangeCommonDateAction(feast));
    probe.didChangeDependencies();

    expect(probe.loaded.last, SelectedDay.keyOf(feast));
  });

  testWidgets("«Повторить» спрашивает тот же день, а не прежний", (tester) async {
    final (_, probe) = await pumpProbe(tester);
    final feast = DateTime(2027, 1, 7);
    probe.goToDay(feast);
    await tester.pump();

    probe.reloadSelectedDay();
    await tester.pump();

    expect(probe.loaded.last, SelectedDay.keyOf(feast));
  });
}
