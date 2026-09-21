import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/text.dart';

/// Списочная ручка отдаёт текст урезанным.
///
/// В `/texts?sort=updated` нет поля `content` вовсе — содержимое в перечне ни к
/// чему, — а `content` объявлен непустым `String`. Один отсутствующий ключ ронял
/// разбор всего списка, а вместе с ним и главную: все три вкладки показывали
/// «не удалось загрузить чтения дня», хотя день был получен и разобран.
///
/// Образец — настоящий ответ сервера.
void main() {
  test("список без content разбирается", () {
    final list = ReadingList.fromJson(
      jsonDecode(File("test/fixtures/live_last_texts.json").readAsStringSync()),
    );

    expect(list.list, isNotEmpty);
    expect(list.list.first.name, isNotEmpty);
    expect(list.list.first.content, "");
  });

  test("пустой ответ не роняет разбор", () {
    expect(ReadingList.fromJson({"items": []}).list, isEmpty);
  });

  test("отсутствие обязательных по типу полей не роняет разбор", () {
    // Списочные проекции вправе не присылать что угодно тяжёлое; падать из-за
    // этого целой страницей — несоразмерно.
    final list = ReadingList.fromJson({
      "items": [
        {"id": "x"},
      ],
    });

    expect(list.list.single.id, "x");
    expect(list.list.single.name, "");
    expect(list.list.single.readiness, "");
    expect(list.list.single.type, "");
  });
}
