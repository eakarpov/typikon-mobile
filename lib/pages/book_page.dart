import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';
import 'package:typikon/components/api_error_view.dart' show searchHint;
import 'package:typikon/components/faceted_search.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/components/dneslov/roundels.dart';
import 'package:typikon/utils/text_type_labels.dart';

class BookPage extends StatefulWidget {
  final String id;

  const BookPage(
    context, {
    super.key,
    required this.id,
    this.loadBook = getBook,
  });

  /// Загрузка книги с текстами. Подменяется тестом, чтобы показать список
  /// без сети.
  final Future<BookWithTexts> Function(String id) loadBook;

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  late Future<BookWithTexts> book;

  /// Отбор по типу текста. `null` — все; сервер таким отбором не занимается,
  /// сужаем уже загруженный список сами.
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    book = widget.loadBook(widget.id);
  }

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  Future<void> _refresh() {
    _retry();
    return settle(book);
  }

  void _retry() {
    setState(() {
      book = widget.loadBook(widget.id);
    });
  }

  /// Типы текстов книги по одному, в порядке первого появления. Пустой тип —
  /// не тип: показать его «как есть» нельзя, подписью была бы пустая строка.
  List<String> _presentTypes(List<BookText> texts) {
    final seen = <String>{};
    final types = <String>[];
    for (final text in texts) {
      final type = text.textType ?? "";
      if (type.isNotEmpty && seen.add(type)) types.add(type);
    }
    return types;
  }

  List<BookText> _filtered(List<BookText> texts) {
    final type = _typeFilter;
    if (type == null) return texts;
    return texts.where((text) => text.textType == type).toList();
  }

  /// Полоса отборов над списком. Значения берутся из уже загруженных текстов,
  /// а не с сервера: сервер отбором по типу не занимается.
  Widget _filters(List<BookText> texts) {
    final types = _presentTypes(texts);
    // Отбор с одним значением ничего не отбирает, а место занимает.
    if (types.length < 2) return const FacetBar(chips: []);

    return FacetBar(
      chips: [
        FacetChoice<String>(
          name: "тип",
          anyLabel: "Все",
          value: _typeFilter,
          values: types,
          nameOf: textTypeLabel,
          onPicked: (value) => setState(() => _typeFilter = value),
        ),
      ],
    );
  }

  /// Отбор не оставил ничего. Плашка — в прокручиваемом списке: RefreshIndicator
  /// выше жест берёт только у прокрутки (см. `AsyncView._short`).
  Widget _emptyFilter() => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: searchHint("Текстов такого типа в этой книге нет."),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<BookWithTexts>(
          future: book,
          builder: (context, future) {
            if (future.hasData) {
              String name = future.data!.name;
              return Text(name);
            } else if (future.hasError) {
              // В заголовке — короткий ярлык, а не вид ошибки: целый экран
              // с «Повторить» показывается ниже, в теле страницы.
              return const Text(
                "Книга",
                style: TextStyle(fontFamily: "OldStandard"),
              );
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      body: AsyncView<BookWithTexts>(
        future: book,
        message: "Не удалось загрузить книгу.",
        onRetry: _retry,
        onRefresh: _refresh,
        isEmpty: (data) => data.texts.isEmpty,
        emptyMessage: "В этой книге пока нет текстов.",
        builder: (context, data) {
          final texts = _filtered(data.texts);
          return Column(
            children: [
              _filters(data.texts),
              Expanded(
                child: texts.isEmpty
                    ? _emptyFilter()
                    : ListView.builder(
                        itemCount: texts.length,
                        itemBuilder: (context, index) =>
                            Roundels(context, item: texts[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
