import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/trapeza.dart';

// Строка о трапезе. Молчать здесь приходится чаще, чем говорить, и важно, чтобы
// молчали ровно там, где сказать нечего: «поста нет» на упавшей службе устава
// было бы враньём о посте, а спор глав, подменённый молчанием, — потерей ответа.

Trapeza parse(String body) => Trapeza.fromJson(jsonDecode(body));

void main() {
  test("сказанное книгой показывается", () {
    final answer = parse('{"kind":"verdict","line":"поста нет, два блюда"}');

    expect(answer.kind, "verdict");
    expect(answer.hasLine, isTrue);
    expect(answer.line, "поста нет, два блюда");
  });

  test("спор глав — это ответ, а не его отсутствие", () {
    // В строку его не сжать, но сказать о нём надо: подменив молчанием, мы
    // потеряли бы то единственное, что про этот день известно.
    final answer = parse('{"kind":"disputed","line":"главы Типикона на этот день расходятся"}');

    expect(answer.hasLine, isTrue);
  });

  test("молчание книги ничего не показывает", () {
    expect(parse('{"kind":"silent","line":null}').hasLine, isFalse);
  });

  test("молчание службы устава — тоже ничего", () {
    // Различие между ним и молчанием книги нужно нам, а не читателю: и там и
    // там мы не знаем, что сказать про пост. Но «поста нет» здесь сказать
    // нельзя ни в коем случае.
    final answer = parse('{"kind":"unavailable","line":null}');

    expect(answer.kind, "unavailable");
    expect(answer.hasLine, isFalse);
  });

  test("пустая строка равна её отсутствию", () {
    expect(parse('{"kind":"verdict","line":""}').hasLine, isFalse);
  });

  test("ответ без вида считается молчанием, а не падает", () {
    final answer = parse('{"line":"что-то"}');

    expect(answer.kind, "silent");
    expect(answer.hasLine, isTrue);
  });
}
