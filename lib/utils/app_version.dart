import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';

/// Есть ли на сервере версия новее установленной.
///
/// Прежнее условие `remote.major > local.major || remote.minor > local.minor`
/// сравнивало числа независимо друг от друга, поэтому сразу после смены мажора
/// версия 2.0 против установленной 1.9 давала верный ответ, а вот 1.9 против
/// установленной 2.0 — ложное "появилось обновление": минор 9 больше нуля.
/// Номер версии — пара, и сравнивать её нужно как пару.
///
/// Проверка живёт в одном месте: раньше это же условие было продублировано в
/// main.dart (фоновое уведомление) и в main_page.dart (диалог при запуске), и
/// разъехаться они могли независимо.
bool isUpdateAvailable(Version remote) {
  if (remote.major != majorVersion) return remote.major > majorVersion;
  return remote.minor > minorVersion;
}
