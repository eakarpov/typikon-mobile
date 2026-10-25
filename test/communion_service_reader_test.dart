import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/posledovanie_page.dart';
import 'package:typikon/dto/posledovanie.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  test('уставное издание: канон перед «Достойно есть», при рубрике «И абие»', () {
    expect(communionCanonIndex(const [
      PosledovanieRow(text: 'Поми́луй мя, Бо́же'),
      PosledovanieRow(label: 'И҆ а҆́бїе', text: 'Досто́йно є҆́сть ꙗ҆́кѡ вои́стиннꙋ'),
    ]), 1);
  });
  for (final part in [
    PosledovaniePart.beforeCommunion,
    PosledovaniePart.communionPrayers,
  ]) {
    testWidgets(
      'последование и молитвы не повторяют друг друга: ${part.name}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var canonLoads = 0;
        await tester.pumpWidget(
          StoreProvider<AppState>(
            store: Store<AppState>(appReducer, initialState: AppState.init()),
            child: MaterialApp(
              home: PosledovaniePage(
                null,
                title: 'Причастие',
                posledovanieKey: 'ko-prichashcheniyu',
                part: part,
                loader: () async => const Posledovanie(
                  rows: [
                    PosledovanieRow(text: 'Псалом перед каноном'),
                    PosledovanieRow(label: 'Песнь 9', text: 'После канона'),
                    PosledovanieRow(
                      label: 'Молитва 1-я, Василия',
                      text: 'Первая молитва',
                    ),
                    PosledovanieRow(text: 'Вторая молитва'),
                  ],
                ),
                canonLoader: () async {
                  canonLoads++;
                  return const CanonDetail(
                    canon: Canon(
                      id: 'c',
                      memory: 'Ко Причащению',
                      language: 'cu_gr',
                    ),
                    odes: [
                      CanonOde(
                        ode: 1,
                        troparia: [
                          CanonLine(text: 'Тропарь канона ко Причастию'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (part == PosledovaniePart.beforeCommunion) {
          expect(canonLoads, 1);
          expect(find.text('Первая молитва'), findsNothing);
          expect(
            find.text('Тропарь канона ко Причастию', findRichText: true),
            findsOneWidget,
          );
          final before = tester.getTopLeft(find.text('Псалом перед каноном'));
          final canon = tester.getTopLeft(
            find.text('Тропарь канона ко Причастию', findRichText: true),
          );
          final after = tester.getTopLeft(find.text('После канона'));
          expect(before.dy, lessThan(canon.dy));
          expect(canon.dy, lessThan(after.dy));
        } else {
          expect(canonLoads, 0);
          expect(find.text('Псалом перед каноном'), findsNothing);
          expect(find.text('Первая молитва'), findsOneWidget);
          expect(find.text('Вторая молитва'), findsOneWidget);
        }
      },
    );
  }
}
