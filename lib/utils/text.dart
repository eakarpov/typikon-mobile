
List<String> getStatias(String content) {
  var regSreda = RegExp(r'\[Среда:]'); // Для ввода ударения если получится, использовать отдельный кейс
  if (regSreda.hasMatch(content)) {
    var parts = content.split(regSreda);
    return parts;
  } else {
    var regStatias = RegExp(r'\[Статия \d+]'); // Для учета двоеточия или ударения если нужно - отдельный кейс, чтобы не сломать обратную совместимость
    if (regStatias.hasMatch(content)) {
      var parts = content.split(regStatias);
      return parts;
    } else {
      return [content];
    }
  }
}

/// Нужная статия текста; [statia] — номер с единицы, как его отдаёт сервер.
///
/// Номер приходит с сервера, а число частей считается здесь, по разметке самого
/// текста, — и сойтись они не обязаны: разметку поправили, а день ссылается на
/// третью статию по-прежнему. Выход за край был исключением прямо в `build`, то
/// есть пустой страницей дня целиком из-за одного чтения. Не нашли — отдаём
/// текст целиком: лишнее прочесть можно, отсутствующее — нет.
String statiaContent(String content, int? statia) {
  final parts = getStatias(content);
  final index = statia != null ? statia - 1 : 0;
  if (index < 0 || index >= parts.length) return content;
  return parts[index];
}

/// Сноска по номеру из метки в тексте; `null`, если такой нет.
///
/// Метку ставит наборщик, список сносок приходит отдельно, и номер без сноски —
/// опечатка в данных, а не повод ронять нажатие исключением.
String? footnoteAt(List<String> footnotes, String? marker) {
  final index = int.tryParse(marker ?? "");
  if (index == null || index < 0 || index >= footnotes.length) return null;
  return footnotes[index];
}
