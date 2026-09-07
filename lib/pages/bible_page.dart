import 'package:flutter/material.dart';

import '../apiMapper/bible.dart';
import '../components/api_error_view.dart';
import '../dto/bible.dart';
import '../utils/bible_route.dart';
import '../utils/bible_sections.dart';

/// Оглавление Библии: разделы канона и книги в них.
///
/// Список плоский, без сворачивающихся разделов: восемь разделов на семьдесят
/// семь книг помещаются в несколько экранов прокрутки, а свёрнутый раздел
/// заставляет читателя гадать, в каком из них Иона.
///
/// Экран сетевой — списка книг в сборке нет, он приходит ручкой. Кэш держится
/// тридцать дней, так что за списком ходят один раз, дальше оглавление
/// открывается офлайн. До первого удачного запроса кэша нет, и тогда честнее
/// показать «нет сети» с кнопкой, чем пустой список. На главный сценарий это не
/// влияет: путь «страница дня → зачало → глава» оглавления не касается.
class BiblePage extends StatefulWidget {
  const BiblePage(context, {super.key});

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  late Future<BibleBookList> books;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    books = getBibleBooks();
  }

  void _openBook(BibleBook book) {
    Navigator.pushNamed(context, "/bible", arguments: bibleRouteArgument(book.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Библия", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: FutureBuilder<BibleBookList>(
        future: books,
        builder: (context, future) {
          if (future.hasError) {
            return ApiErrorView(
              error: future.error,
              message: "Не удалось загрузить оглавление Библии.",
              offlineMessage: "Оглавление ещё не загружалось, а сети сейчас нет.",
              hint: "Один раз оно скачается — и дальше будет открываться без сети.",
              onRetry: () => setState(_load),
            );
          }
          if (!future.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Первая итерация показывает только канон. Книги приложения сервер
          // отдаёт и помечает, но у каждой своя длинная оговорка о том, почему
          // она вне канона; без неё читатель получит книги, которых не найдёт ни
          // в одном привычном издании, и решит, что у нас в оглавлении мусор.
          final groups = groupBySection(future.data!.canon);

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) => _section(context, groups[index]),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, BibleSectionGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 4.0),
          child: Text(
            group.label,
            style: TextStyle(
              fontFamily: "OldStandard",
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...group.books.map(
          (book) => ListTile(
            dense: true,
            title: Text(book.name, style: const TextStyle(fontFamily: "OldStandard")),
            trailing: book.chapters == null
                ? null
                : Text(
                    "${book.chapters}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            onTap: () => _openBook(book),
          ),
        ),
      ],
    );
  }
}
