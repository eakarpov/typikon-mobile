import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../apiMapper/v2/errors.dart';
import '../components/api_error_view.dart';
import '../components/note_sheet.dart';
import '../components/sign_in_needed.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// ПОДАННЫЕ ЗАПИСКИ — сторона священника.
///
/// **Неразобранные сверху**: за ними и приходят. Порядок задаёт сервер, и
/// пересортировывать его здесь не надо.
///
/// **Прочтение отмечается одним нажатием.** Священник у аналоя, а не за столом,
/// и трёх нажатий на записку у него нет.
///
/// **Сказано, где склонение наше.** Имя, которого нет в словаре, приходит в том
/// падеже, в каком его вписал подавший, и молча выдать это за проверенный
/// родительный значило бы подсунуть читающему ошибку, которой он не делал.
///
/// Приём не открыт — сервер отвечает отказом, и мы показываем его слова, а не
/// пустой список: пустой означал бы «вам никто не подавал», а правды в этом нет.
class PomyannikPrinyatyePage extends StatefulWidget {
  const PomyannikPrinyatyePage(context, {super.key});

  @override
  State<PomyannikPrinyatyePage> createState() => _PomyannikPrinyatyePageState();
}

class _PomyannikPrinyatyePageState extends State<PomyannikPrinyatyePage> {
  late Future<Prinyatye> notes;
  Vocabulary _vocabulary = const Vocabulary();
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _loadVocabulary();
  }

  void _load() {
    notes = getReceivedNotes();
  }

  Future<void> _loadVocabulary() async {
    try {
      final vocabulary = await getVocabulary();
      if (mounted) setState(() => _vocabulary = vocabulary);
    } catch (_) {}
  }

  Future<void> _mark(Zapiska note, String what) async {
    setState(() => _busy.add(note.id));
    try {
      await markNote(note.id, what);
      if (mounted) setState(_load);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => _busy.remove(note.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Поданные записки", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<Prinyatye>(
          future: notes,
          builder: (context, future) {
            if (future.error is SessionExpiredException) {
              return const SignInNeeded(
                message: "Поданные вам записки видны только вам — для этого нужен вход.",
              );
            }

            // Приём не открыт. Это не поломка и не пустота, а ответ, и сказан он
            // словами сервера.
            if (future.error is ApiUnauthorizedException) {
              return _NoAcceptance(message: "${future.error}");
            }

            if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось открыть поданные записки.",
                onRetry: () => setState(_load),
              );
            }

            if (!future.hasData) return const Center(child: CircularProgressIndicator());

            final data = future.data!;
            if (data.items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text("Записок пока не подавали.", textAlign: TextAlign.center),
                ),
              );
            }

            return ListView.builder(
              itemCount: data.items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _Head(data: data);

                final note = data.items[index - 1];
                return _Note(
                  note: note,
                  vocabulary: _vocabulary,
                  busy: _busy.contains(note.id),
                  onMark: (what) => _mark(note, what),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.data});

  final Prinyatye data;

  @override
  Widget build(BuildContext context) {
    final about = [
      data.commemorator.title,
      if ((data.commemorator.place ?? "").isNotEmpty) data.commemorator.place!,
    ].join(", ");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(about, style: const TextStyle(fontFamily: "OldStandard")),
          Text(
            data.unread == 0
                ? "всё разобрано, всего записок ${data.total}"
                : "не разобрано ${data.unread} из ${data.total}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.note,
    required this.vocabulary,
    required this.busy,
    required this.onMark,
  });

  final Zapiska note;
  final Vocabulary vocabulary;
  final bool busy;
  final void Function(String what) onMark;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final kind = vocabulary.noteKinds
        .where((k) => k.key == note.kind)
        .map((k) => k.label)
        .firstOrNull;

    final sheet = NoteSheet(
      kind: NoteKindInfo(key: note.kind, label: kind ?? note.kind, about: "both"),
      names: note.names,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          // Неразобранная видна сразу: за ними и приходят.
          color: note.unread
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: note.unread ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                kind ?? note.kind,
                if (note.span != null)
                  "с ${humanDate(note.span!.from)} по ${humanDate(note.span!.to)}",
              ].join(", "),
              style: small,
            ),
            const SizedBox(height: 12.0),
            if (note.swept)
              // Стираются ИМЕНА, а не запись: они принадлежат третьим лицам, и
              // держать их после поминовения не за что.
              Text(
                "Имена стёрты по сроку хранения: было ${note.namesCount}.",
                style: small,
              )
            else ...[
              NoteSheetView(sheet: sheet, vocabulary: vocabulary, cross: false),
              NoteSheetCaveats(sheet: sheet, vocabulary: vocabulary),
            ],
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (note.unread && !busy)
                  TextButton(
                    onPressed: () => onMark("read"),
                    child: const Text("Прочитано"),
                  ),
                if (note.finishable && !busy)
                  TextButton(
                    onPressed: () => onMark("finished"),
                    child: const Text("Поминовение окончено"),
                  ),
                if (busy)
                  const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                if (!note.unread && !note.finishable && !busy)
                  Text(
                    note.finishedAt != null ? "окончено" : "прочитано",
                    style: small,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAcceptance extends StatelessWidget {
  const _NoAcceptance({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 48.0),
            const SizedBox(height: 16.0),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12.0),
            Text(
              "Приём открывается на сайте: нужен адрес страницы епархии, где вы названы, и "
              "ответ с почты в её домене. Сана мы не удостоверяем — сверяем эти две вещи, и "
              "это всё, за что отвечаем.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
