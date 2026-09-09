import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/text.dart';
import 'package:typikon/store/models/settings.dart';

// Показ с ударениями. Настройка и признак «предлагать ли» — два разных решения,
// и путать их нельзя: первое говорит, чего хочет читатель, второе — есть ли что
// показывать в этом тексте.

void main() {
  group("настройка", () {
    test("по умолчанию книга показывается как есть", () {
      expect(const Settings().showAccents, isFalse);
    });

    test("состояние прежней версии не включает ударений само", () {
      expect(Settings.fromJson({"fontSize": 16}).showAccents, isFalse);
    });

    test("выбор переживает запись и чтение", () {
      expect(Settings.fromJson(const Settings(showAccents: true).toJson()).showAccents, isTrue);
    });

    test("равенство различает показ", () {
      // Иначе экран не перерисуется после переключения.
      const base = Settings();
      expect(base == base.copyWith(showAccents: true), isFalse);
    });
  });

  group("предлагать ли", () {
    test("текст без знаков — предлагаем", () {
      final coverage = AccentCoverage.fromJson({"need": 217, "has": 0});

      expect(coverage, isNotNull);
      expect(coverage!.missing, 217);
    });

    test("размеченный текст — не предлагаем", () {
      // Переключатель, ничего не меняющий, только сбивает.
      expect(AccentCoverage.fromJson({"need": 100, "has": 100}), isNull);
      expect(AccentCoverage.fromJson(null), isNull);
    });

    test("мусор вместо покрытия — не предлагаем, а не падаем", () {
      expect(AccentCoverage.fromJson({"need": "много"}), isNull);
      expect(AccentCoverage.fromJson("да"), isNull);
    });
  });

  group("разбор ответа", () {
    test("вид, счёт и род читаются", () {
      final view = AccentedText.fromJson(jsonDecode('''
        {"content": "сло́во", "marked": 189, "expected": 196, "genre": "chant"}
      '''));

      expect(view.content, "сло́во");
      expect(view.marked, 189);
      expect(view.expected, 196);
      expect(view.genre, "chant");
    });

    test("незнакомый род считается чтением", () {
      // Умолчание разметчика, и оно же верно для большинства корпуса.
      expect(AccentedText.fromJson({"content": "", "genre": "песнь"}).genre, "reading");
    });

    test("текст берётся с признаком покрытия", () {
      final reading = Reading.fromJson(jsonDecode('''
        {"id": "1", "name": "Служба", "content": "текст", "readiness": "ready",
         "type": "Teaching", "accents": {"need": 217, "has": 0}}
      '''), null);

      expect(reading.accents?.missing, 217);
    });
  });
}
