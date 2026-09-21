import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/utils/pomyannik_import.dart';

/// Разбор списка имён. Словарь чинов — настоящий, с сервера.
void main() {
  final vocabulary = Vocabulary.fromJson(
    jsonDecode(File("test/fixtures/pomyannik_vocabulary.json").readAsStringSync()),
  );

  ImportResult parse(String text, {String kind = living}) =>
      parseNameList(text, ranks: vocabulary.ranks, kind: kind);

  test("имя на строку", () {
    final result = parse("Иоанна\nМарии\nНиколая");

    expect(result.names.map((n) => n.name), ["Иоанна", "Марии", "Николая"]);
    expect(result.names.every((n) => n.rank == null), isTrue);
  });

  group("чин отделяется от имени", () {
    test("полной формой — именительной и родительной", () {
      final result = parse("протоиерея Иоанна\nмладенец Мария\nвоина Александра");

      expect(result.names.map((n) => "${n.rank}:${n.name}"),
          ["protoierey:Иоанна", "mladenets:Мария", "voin:Александра"]);
    });

    test("сокращением с точкой", () {
      // Таблицы сокращений нет нарочно: она всё равно не угадала бы, кто как
      // сокращает, — сверяется начало слова.
      final result = parse("прот. Иоанна\nмл. Марии\nмон. Иосифа\nархим. Тихона");

      expect(result.names.map((n) => n.rank),
          ["protoierey", "mladenets", "monah", "arhimandrit"]);
    });

    test("женской формой", () {
      final result = parse("монахини Евдокии\nигумении Феодоры");

      expect(result.names.map((n) => n.rank), ["monah", "igumen"]);
    });

    test("через «ё» и «е» одинаково", () {
      expect(parse("заключенного Петра").names.single.rank, "zaklyuchennyy");
      expect(parse("заключённого Петра").names.single.rank, "zaklyuchennyy");
    });

    test("обиходное сокращение читается по обычаю", () {
      // «Прот.» подходит и протоиерею, и протодиакону; в обиходе за ним
      // закреплено одно чтение, и правило по началу слова его не выведет.
      expect(parse("прот. Иоанна").names.single.rank, "protoierey");
      expect(parse("протод. Стефана").names.single.rank, "protodiakon");
      expect(parse("иер. Василия").names.single.rank, "ierey");
      expect(parse("иером. Серафима").names.single.rank, "ieromonah");
      expect(parse("архим. Тихона").names.single.rank, "arhimandrit");
      expect(parse("архиер. Николая").names.single.rank, "arhierey");
    });

    test("неоднозначное сокращение не берётся", () {
      // «и.» подходит иерею, игумену, иеромонаху и иноку. Поставить любого
      // наугад значит приписать человеку сан, которого у него нет.
      final parsed = parse("и. Василия").names.single;

      expect(parsed.rank, isNull);
      expect(parsed.name, "и. Василия");
    });

    test("чин не из этого столбца не ставится", () {
      // «Убиенный» бывает только об усопших, «болящий» — только о живых.
      expect(parse("убиенного Георгия", kind: living).names.single.rank, isNull);
      expect(parse("убиенного Георгия", kind: departed).names.single.rank, "ubiennyy");
      expect(parse("болящей Анны", kind: departed).names.single.rank, isNull);
    });
  });

  test("нумерация и маркеры списка срезаются", () {
    final result = parse("1. Иоанна\n2) Марии\n— Николая\n• Анны\n* Петра");

    expect(result.names.map((n) => n.name),
        ["Иоанна", "Марии", "Николая", "Анны", "Петра"]);
  });

  test("заголовки столбцов не становятся именами", () {
    final result = parse("О здравии:\nИоанна\nМарии\n\nО упокоении\nНиколая");

    expect(result.names.map((n) => n.name), ["Иоанна", "Марии", "Николая"]);
    expect(result.headers.length, 2);
  });

  test("родство в скобках отделяется", () {
    final parsed = parse("Анны (мама)").names.single;

    expect(parsed.name, "Анны");
    expect(parsed.relation, "мама");
  });

  test("повтор в одном списке берётся один раз", () {
    // Список у людей писан годами, и одно имя в нём встречается дважды.
    final result = parse("Иоанна\nмл. Марии\nиоанна\nмладенца Марии");

    expect(result.names.length, 2);
    expect(result.duplicates.length, 2);
  });

  test("исходная строка сохраняется — по ней человек узнаёт своё", () {
    final parsed = parse("  1. прот. Иоанна  ").names.single;

    expect(parsed.raw, "1. прот. Иоанна");
    expect(parsed.name, "Иоанна");
  });

  test("пустое и мусор не роняют разбор", () {
    expect(parse("").names, isEmpty);
    expect(parse("\n\n   \n").names, isEmpty);
    expect(parse("— \n1.").names, isEmpty);
  });

  test("что уходит на сервер", () {
    final parsed = parse("прот. Иоанна (крёстный)").names.single;

    expect(parsed.toInput(departed), {
      "name": "Иоанна",
      "kind": departed,
      "rank": "protoierey",
      "relation": "крёстный",
    });
  });
}
