import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/apiMapper/session.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/favourites_sync.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 25, 10, 0);

  Store<AppState> signedIn() {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    store.dispatch(SignInSuccessAction(userId: "user-1"));
    return store;
  }

  setUp(resetFavouritesSyncState);

  test("не вошедшему в сеть не ходим вовсе", () async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    store.dispatch(ToggleFavouriteAction("a", at: t0));
    var called = false;

    await syncFavourites(store,
        push: (id, {required isAdd}) async => called = true,
        fetch: () async {
          called = true;
          return [];
        });

    expect(called, isFalse);
    expect(store.state.favourites.contains("a"), isTrue,
        reason: "избранное работает и без аккаунта");
  });

  test("очередь уезжает на сервер и очищается", () async {
    final store = signedIn();
    store.dispatch(ToggleFavouriteAction("a", at: t0));
    final sent = <String>[];

    await syncFavourites(store,
        push: (id, {required isAdd}) async => sent.add("$id:$isAdd"),
        fetch: () async => ["a"]);

    expect(sent, ["a:true"]);
    expect(store.state.favourites.pending, isEmpty);
    expect(store.state.favourites.textIds, ["a"]);
  });

  test("не отправленное остаётся в очереди на следующий раз", () async {
    final store = signedIn();
    store.dispatch(ToggleFavouriteAction("a", at: t0));

    await syncFavourites(store,
        push: (id, {required isAdd}) async => throw Exception("нет сети"),
        fetch: () async => []);

    expect(store.state.favourites.pending.length, 1);
    expect(store.state.favourites.contains("a"), isTrue,
        reason: "для пользователя отметка на месте, даже если сервер её ещё не знает");
  });

  test("сбой сети не роняет вызов наверх", () async {
    final store = signedIn();

    await expectLater(
      syncFavourites(store,
          push: (id, {required isAdd}) async {},
          fetch: () async => throw Exception("нет сети")),
      completes,
    );
  });

  test("истёкшая сессия не теряет очередь", () async {
    final store = signedIn();
    store.dispatch(ToggleFavouriteAction("a", at: t0));

    await syncFavourites(store,
        push: (id, {required isAdd}) async => throw const SessionExpiredException(),
        fetch: () async => []);

    expect(store.state.favourites.pending.length, 1);
  });

  group("первый вход", () {
    test("локальный список вливается, а не затирается", () async {
      final store = signedIn();
      store.dispatch(ToggleFavouriteAction("своё", at: t0));
      // очередь уже отправлена в прошлый раз
      store.dispatch(FavouritesQueueConfirmedAction(store.state.favourites.pending));

      List<String>? merged;
      await syncFavourites(store,
          mergeLocal: true,
          push: (id, {required isAdd}) async {},
          merge: (ids) async {
            merged = ids;
            return ["своё", "с-сервера"];
          });

      expect(merged, ["своё"], reason: "на сервер уходит то, что накопилось на устройстве");
      expect(store.state.favourites.textIds, ["своё", "с-сервера"]);
    });

    test("без слияния список просто забирается с сервера", () async {
      final store = signedIn();
      var mergeCalled = false;

      await syncFavourites(store,
          push: (id, {required isAdd}) async {},
          fetch: () async => ["с-сервера"],
          merge: (ids) async {
            mergeCalled = true;
            return ids;
          });

      expect(mergeCalled, isFalse);
      expect(store.state.favourites.textIds, ["с-сервера"]);
    });
  });

  test("две синхронизации подряд не шлют очередь дважды", () async {
    final store = signedIn();
    store.dispatch(ToggleFavouriteAction("a", at: t0));
    var pushes = 0;

    final first = syncFavourites(store,
        push: (id, {required isAdd}) async {
          pushes++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        },
        fetch: () async => ["a"]);
    await syncFavourites(store,
        push: (id, {required isAdd}) async => pushes++,
        fetch: () async => ["a"]);
    await first;

    expect(pushes, 1);
  });
}
