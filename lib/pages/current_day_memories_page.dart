import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/calendar.dart';
import 'package:typikon/dto/day_saints.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/components/async_view.dart';
import 'package:typikon/utils/selected_day.dart';

/// Полный календарь Днеслова и собственные дополнения через серверный кэш.
/// Без внешнего снимка сервер помечает неполную выдачу, и страница называет её.
/// Гражданская дата уходит на сервер; старый стиль рассчитывается там.
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
        builder: (context, data) => data.saints.isEmpty && !data.partial
            ? _empty(context)
            : ListView.builder(
                itemCount: data.saints.length + (data.partial ? 1 : 0),
                itemBuilder: (context, index) {
                  if (data.partial && index == 0) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Днеслов сейчас недоступен, сохранённого списка на эту дату пока нет. Показана только наша коллекция.',
                      ),
                    );
                  }
                  final saint = data.saints[index - (data.partial ? 1 : 0)];
                  return ListTile(
                    onTap: saint.slug.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
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
                    "На эту дату в объединённом календаре пока нет памятей.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Список объединяет Днеслов и наш каталог. Если ожидаемой памяти "
                    "нет, проверьте сведения у источника.",
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
