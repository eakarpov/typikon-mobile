import '../dto/bible.dart';
import 'bible_style.dart';

/// Какие издания просить у сервера.
///
/// Выбранное читателем — если оно ещё существует и его есть чем нарисовать.
/// Иначе эталон: он же и есть та нумерация, которой записаны зачала Типикона.
/// Иначе первое, что сборка умеет показать.
///
/// Код издания по умолчанию не зашивается: `cs-eliz` в приложении был бы шестой
/// копией списка изданий, и разошлась бы она молча. Эталон узнаётся признаком
/// `versification == "sla-lxx"` — тем же, которым его узнаёт сервер.
///
/// Пустой ответ — не ошибка: пустой набор изданий сервер понимает как «все
/// публичные», и худшее, что получит читатель, глава во всех изданиях сразу, а
/// не пустой экран.
List<String> resolveEditionCodes(List<String> chosen, BibleEditionList available) {
  final renderable = available.list.where(canRenderEdition).toList();
  if (renderable.isEmpty) return const [];

  final codes = renderable.map((edition) => edition.code).toSet();
  final kept = chosen.where(codes.contains).toList();
  if (kept.isNotEmpty) return kept;

  for (final edition in renderable) {
    if (edition.isReference) return [edition.code];
  }
  return [renderable.first.code];
}
