
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