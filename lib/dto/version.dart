/// Версия приложения, выложенная на сервере.
///
/// **Номер — тройка.** Первая версия API отдавала только `major` и `minor`, и
/// патч приходит нулём с тех ручек; на сравнение это не влияет, пока патчи не
/// выпускаются отдельно, а когда начнут — приложение уже готово.
///
/// **Откуда скачать, говорит сервер.** Прежде адрес выпуска был склеен в
/// приложении из своего же корня. Это переживёт переезд домена: старая копия
/// узнает новый адрес выпуска от сервера, а не от собственной константы.
class Version {
  final int major;
  final int minor;
  final int patch;

  /// Адрес выпуска. Пустой — значит сервер его не назвал (первая версия API);
  /// тогда приложение берёт свой прежний.
  final String download;

  const Version({
    required this.major,
    required this.minor,
    this.patch = 0,
    this.download = "",
  });

  static int _int(Object? value) => value is int ? value : 0;

  factory Version.fromJson(Map<String, dynamic> json) => Version(
        major: _int(json["major"]),
        minor: _int(json["minor"]),
        patch: _int(json["patch"]),
        download: json["download"] is String ? json["download"] : "",
      );

  @override
  String toString() => "$major.$minor.$patch";
}
