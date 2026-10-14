import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/calendar.dart';
import 'package:typikon/dto/day_saints.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/components/async_view.dart';
import 'package:typikon/utils/selected_day.dart';

/// Святые выбранного дня из нашего каталога.
///
/// Покрытие связей памятей с каталогом ещё маленькое (88 из 653), поэтому
/// пустой день — честное состояние, а не отказ: страница объясняет это и даёт
/// выход на dneslov.org. Старого стиля страница не знает: дату по юлианскому
/// календарю накладывает сервер.
class CurrentDayMemoriesPage extends StatefulWidget {
  const CurrentDayMemoriesPage(
    context, {
    super.key,
    this.loadSaints = getDaySaints,
  });

  /// Загрузка святых дня. Подменяется тестом, чтобы показать список без сети.
  final Future<DaySaints> Function(String date) loadSaints;

  @override
  State<CurrentDayMemoriesPage> createState() => _CurrentDayMemoriesPageState();
}

class _CurrentDayMemoriesPageState extends State<CurrentDayMemoriesPage>
    with WidgetsBindingObserver, SelectedDay {
  late Future<DaySaints> currentDay;

  /// Как эта страница грузит свой день; когда и по какому поводу — знает
  /// примесь SelectedDay.
  @override
  void loadDay(DateTime day) {
    currentDay = widget.loadSaints(SelectedDay.keyOf(day));
  }

  Future<void> _refresh() {
    reloadSelectedDay();
    return settle(currentDay);
  }

  void _openDneslov() => launchUrl(
    Uri.parse("https://dneslov.org/"),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    String value = format.format(
      StoreProvider.of<AppState>(context).state.common.date,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(value, style: TextStyle(fontFamily: "OldStandard")),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () {
              pickDay();
            },
          ),
        ],
      ),
      body: AsyncView<DaySaints>(
        future: currentDay,
        message: "Не удалось загрузить святых дня.",
        onRetry: reloadSelectedDay,
        onRefresh: _refresh,
        builder: (context, data) => data.saints.isEmpty
            ? _empty(context)
            : ListView.builder(
                itemCount: data.saints.length,
                itemBuilder: (context, index) {
                  final saint = data.saints[index];
                  return ListTile(
                    onTap: () => Navigator.pushNamed(
                      context,
                      "/saints",
                      arguments: saint.slug,
                    ),
                    leading: saint.roundelUrl != null
                        ? ClipOval(
                            child: Image.network(
                              saint.roundelUrl!,
                              width: 40.0,
                              height: 40.0,
                              fit: BoxFit.cover,
                              // Образ с чужого CDN: не загрузился — просто нет образа.
                              errorBuilder: (context, error, stack) =>
                                  const SizedBox.shrink(),
                            ),
                          )
                        : null,
                    title: Text(
                      saint.name,
                      style: TextStyle(fontFamily: "OldStandard"),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Пустой день. Плашка — в прокручиваемом списке: RefreshIndicator выше жест
  /// берёт только у прокрутки (см. `AsyncView._short`).
  Widget _empty(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "В нашем каталоге пока нет связанных святых на этот день.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Каталог молод и растёт: связи памятей со святыми выверены "
                    "у 88 из 653 записей. Пустой день здесь — обычное дело, "
                    "а не поломка.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _openDneslov,
                    child: const Text("Открыть dneslov.org"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
