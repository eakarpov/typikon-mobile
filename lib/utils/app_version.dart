import 'package:typikon/api/constants.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';

/// Есть ли на сервере версия новее установленной.
///
/// Прежнее условие `remote.major > local.major || remote.minor > local.minor`
/// сравнивало числа независимо друг от друга, поэтому сразу после смены мажора
/// версия 2.0 против установленной 1.9 давала верный ответ, а вот 1.9 против
/// установленной 2.0 — ложное "появилось обновление": минор 9 больше нуля.
/// Номер версии — не набор чисел, а последовательность, и сравнивается она по
/// порядку: старшее число решает, и только при равенстве смотрим следующее.
///
/// Проверка живёт в одном месте: раньше это же условие было продублировано в
/// main.dart (фоновое уведомление) и в main_page.dart (диалог при запуске), и
/// разъехаться они могли независимо.
bool isUpdateAvailable(Version remote) {
  if (remote.major != majorVersion) return remote.major > majorVersion;
  if (remote.minor != minorVersion) return remote.minor > minorVersion;
  return remote.patch > patchVersion;
}

/// Откуда брать выпуск.
///
/// Адрес называет сервер; свой прежний остаётся на случай, когда не назвал —
/// так отвечала первая версия API, и так ответит она же старым копиям. Это же
/// переживёт переезд домена: адрес выпуска приедет новым, а не будет склеен из
/// прежнего корня.
String updateUrl(Version remote) =>
    remote.download.isEmpty ? '$apiBaseUrl/app/app.apk' : remote.download;
