import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../store/pomyannik_cache.dart';
import '../store/store.dart';
import '../components/api_error_view.dart';
import '../components/sign_in_needed.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// Ближайшее — то, ради чего помянник и открывают между службами: не список
/// имён, а вопрос «кого поминать на этой неделе».
///
/// Окно считается **от местного сегодня**, а не от серверного: часовой пояс
/// телефона свой, и в час пополуночи серверное «сегодня» бывает вчерашним.
class PomyannikUpcomingPage extends StatefulWidget {
  const PomyannikUpcomingPage(context, {super.key});

  @override
  State<PomyannikUpcomingPage> createState() => _PomyannikUpcomingPageState();
}

const int _windowDays = 60;

class _PomyannikUpcomingPageState extends State<PomyannikUpcomingPage> {
  late Future<Upcoming> upcoming;
  late String _from;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _from = today();
    upcoming = getUpcoming(from: _from, days: _windowDays);

    // Заодно обновляем зеркало, из которого складывается напоминание: данные уже
    // на руках, и второго запроса ради них не нужно. Обновляется оно только из
    // работающего приложения — в фоне сессию продлить нечем (см.
    // `refreshPomyannikMirror`).
    upcoming.then((value) async {
      final userId = appStore?.state.auth.userId;
      if (userId == null || userId.isEmpty) return;
      await writePomyannikMirror(
        PomyannikMirror(
          userId: userId,
          fetchedAt: DateTime.now(),
          from: value.from.isEmpty ? _from : value.from,
          days: value.days,
          events: value.events,
        ),
        withNames: await namesInReminders(),
      );
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ближайшее", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<Upcoming>(
          future: upcoming,
          builder: (context, future) {
            if (future.error is SessionExpiredException) {
              return const SignInNeeded(
                message: "Помянник хранится при вашей учётной записи и виден только вам.",
              );
            }

            if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось посчитать ближайшие дни.",
                onRetry: () => setState(_load),
              );
            }

            if (!future.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = future.data!.events;
            if (events.isEmpty) {
              return const _Quiet(
                "В ближайшие два месяца поминальных дней по вашему помяннику нет.",
              );
            }

            return ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) => _Event(
                event: events[index],
                from: future.data!.from,
                // Заголовок дня — только у первого события этого дня: в один
                // день их бывает несколько, и повторённая дата разбивала бы их
                // на отдельные с виду записи.
                showDate: index == 0 || events[index - 1].date != events[index].date,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Event extends StatelessWidget {
  const _Event({required this.event, required this.from, required this.showDate});

  final UpcomingEvent event;
  final String from;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final away = daysBetween(from, event.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
            child: Row(
              children: [
                Text(
                  "${humanDate(event.date, withYear: false)}, ${weekdayOf(event.date)}",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                if (away != null) ...[
                  const SizedBox(width: 8.0),
                  Text(inDays(away), style: small),
                ],
              ],
            ),
          ),
        ListTile(
          dense: true,
          title: Text(event.title, style: const TextStyle(fontFamily: "OldStandard")),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.years == null
                    ? eventLabel(event.kind)
                    : "${eventLabel(event.kind)} — ${years(event.years!)}",
                style: small,
              ),
              // День не уставный — определение Собора, указ или местный обычай.
              // Без пометы список выглядел бы уставным целиком.
              if (event.custom)
                Text(
                  event.note == null ? "день не уставный" : "день не уставный: ${event.note}",
                  style: small?.copyWith(fontStyle: FontStyle.italic),
                ),
            ],
          ),
          onTap: event.personId == null
              ? null
              : () => Navigator.pushNamed(context, "/pomyannik", arguments: event.personId),
        ),
      ],
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
