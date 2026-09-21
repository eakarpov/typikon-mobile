import 'dart:async';

import 'package:flutter/material.dart';

/// Поле поиска с паузой перед отправкой.
///
/// Пауза, крестик очистки и сам контроллер были переписаны в семи местах —
/// в каноны, акафисты, молитвы, места, словарь, именины и поиск, — и уже
/// разошлись: где-то 400 миллисекунд, где-то 500; каноны не звали `setState`
/// при наборе, отчего крестик появлялся с опозданием на всю паузу; словарь и
/// именины дёргали `setState` из таймера без проверки, жив ли ещё экран.
///
/// Наружу отдаётся только устоявшийся запрос — тот, по которому и вправду надо
/// искать. Набор буквы за буквой наружу не выходит.
class SearchQueryField extends StatefulWidget {
  const SearchQueryField({
    super.key,
    required this.hintText,
    required this.onQuery,
    this.autofocus = false,
    this.delay = const Duration(milliseconds: 400),
  });

  final String hintText;

  /// Запрос, по которому пора искать. Зовётся после паузы и на очистку.
  final ValueChanged<String> onQuery;

  final bool autofocus;
  final Duration delay;

  @override
  State<SearchQueryField> createState() => _SearchQueryFieldState();
}

class _SearchQueryFieldState extends State<SearchQueryField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// Последнее, что отдали наружу. Тот же запрос второй раз не отдаём: пауза
  /// срабатывает и на пробел в конце, а лишний запрос — лишняя выдача.
  String _sent = "";

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // setState — ради крестика: он появляется и пропадает по тому, пусто ли
    // поле, и без перерисовки запаздывал бы на всю паузу.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(widget.delay, () => _send(value.trim()));
  }

  void _send(String query) {
    if (!mounted || query == _sent) return;
    _sent = query;
    widget.onQuery(query);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    _send("");
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      // По «искать» на клавиатуре — сразу, не дожидаясь паузы.
      onSubmitted: (value) {
        _debounce?.cancel();
        _send(value.trim());
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: "Очистить",
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Полоса отборов над выдачей. Пустая — не занимает места вовсе.
class FacetBar extends StatelessWidget {
  const FacetBar({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        children: chips,
      ),
    );
  }
}

/// Отбор по одному из значений — или по любому.
///
/// [name] — как отбор зовётся («глас», «книга»), он же стоит на метке, пока
/// ничего не выбрано. [nameOf] — как назвать значение.
class FacetChoice<T> extends StatelessWidget {
  const FacetChoice({
    super.key,
    required this.name,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onPicked,
    this.anyLabel,
  });

  final String name;
  final T? value;
  final List<T> values;
  final String Function(T value) nameOf;
  final void Function(T? value) onPicked;

  /// Как назвать «не отбирать». По умолчанию — «любая <name>».
  final String? anyLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: PopupMenuButton<T?>(
        tooltip: name,
        onSelected: onPicked,
        itemBuilder: (context) => [
          PopupMenuItem<T?>(value: null, child: Text(anyLabel ?? "любая $name")),
          ...values.map(
            (item) => PopupMenuItem<T?>(value: item, child: Text(nameOf(item))),
          ),
        ],
        child: Chip(
          label: Text(value == null ? name : nameOf(value as T)),
          avatar: Icon(
            value == null ? Icons.filter_list : Icons.check,
            size: 16.0,
          ),
        ),
      ),
    );
  }
}
