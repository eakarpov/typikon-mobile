/// Ответ о трапезе на день — одна строка.
///
/// Полного разбора (правила, главы Типикона, цитаты, расхождения глав) наружу
/// сервер не отдаёт: он весит семнадцать килобайт на день и нужен странице
/// сайта, а не строке над чтениями.
class Trapeza {
  /// `verdict` — книга сказала; `disputed` — главы расходятся; `silent` — книга
  /// молчит либо всё, что есть, наш вывод; `unavailable` — не ответила служба
  /// устава.
  final String kind;

  /// Сама строка. Пуста у всего, кроме `verdict` и `disputed`.
  final String? line;

  const Trapeza({required this.kind, this.line});

  /// Есть ли что показать.
  ///
  /// `silent` и `unavailable` различаются для нас, но читателю по ним сказать
  /// нечего: и там и там мы не знаем, что сказать про пост. А `disputed` — это
  /// ответ, а не его отсутствие, и подменять его молчанием нельзя.
  bool get hasLine => line != null && line!.isNotEmpty;

  factory Trapeza.fromJson(Map<String, dynamic> json) {
    final line = json["line"];
    return Trapeza(
      kind: json["kind"] is String ? json["kind"] as String : "silent",
      line: line is String && line.isNotEmpty ? line : null,
    );
  }
}
