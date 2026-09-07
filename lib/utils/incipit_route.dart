/// Аргумент маршрута `/incipit`: язык и сам зачин.
///
/// У зачина нет своего идентификатора — ключ и есть идентификатор. Значит в
/// аргументе едут две части, и разделитель приходится выбирать так, чтобы он не
/// встретился внутри ключа. Ключ — это шесть слов, приведённых к общему виду:
/// строчные буквы, цифры и пробелы, всё прочее свёрнуто. Поэтому разделителем
/// взят перевод строки: в ключе его нет и быть не может, тогда как двоеточие,
/// решётка или косая черта в чужом языке однажды встретятся.
const String _separator = "\n";

class IncipitTarget {
  final String language;
  final String incipit;

  const IncipitTarget(this.language, this.incipit);

  bool get isValid => language.isNotEmpty && incipit.isNotEmpty;
}

String incipitRouteArgument(String language, String incipit) =>
    "$language$_separator$incipit";

IncipitTarget parseIncipitArgument(String raw) {
  final at = raw.indexOf(_separator);
  if (at == -1) return const IncipitTarget("", "");
  return IncipitTarget(raw.substring(0, at), raw.substring(at + 1));
}
