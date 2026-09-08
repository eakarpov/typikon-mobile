import 'package:flutter/material.dart';

/// Готовые пары «фон — текст».
///
/// Пары, а не два пикера порознь: цвета фона и текста осмысленны только вместе.
/// Выбранные по отдельности, они легко сходятся в нечитаемое — тёмный текст на
/// тёмном, — и вернуться из этого можно только сбросом. Пикеры остаются для
/// тех, кому нужен свой цвет.
///
/// Те же четыре, что на сайте: текст в обоих местах выглядит одинаково.
class ReadingScheme {
  final String id;
  final String label;
  final Color background;
  final Color foreground;

  const ReadingScheme({
    required this.id,
    required this.label,
    required this.background,
    required this.foreground,
  });
}

const List<ReadingScheme> readingSchemes = [
  ReadingScheme(
    id: "parchment", label: "Пергамент",
    background: Color(0xfffcfaf2), foreground: Color(0xff1c1917),
  ),
  ReadingScheme(
    id: "paper", label: "Белый",
    background: Color(0xffffffff), foreground: Color(0xff111827),
  ),
  ReadingScheme(
    id: "sepia", label: "Сепия",
    background: Color(0xfff4ecd8), foreground: Color(0xff3b2f2f),
  ),
  ReadingScheme(
    id: "dark", label: "Тёмный",
    background: Color(0xff1c1917), foreground: Color(0xffe7e5e4),
  ),
];
