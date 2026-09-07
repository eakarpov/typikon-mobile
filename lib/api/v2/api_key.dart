import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../utils/crash_reporter.dart';

/// Ключ доступа ко второй версии API.
///
/// Он не секрет — лежит в `.env`, который объявлен ассетом и уезжает внутрь APK,
/// а APK у всех. Он ничего не защищает, он ОТМЕРЯЕТ: без него сервер считает
/// приложение анонимом и отпускает шестьдесят запросов в час на адрес сети. Один
/// читатель столько не выбирает, а приходский Wi-Fi, где десяток человек
/// открывают чтения разом, выбирает за десяток глав — и «слишком часто» получают
/// все сразу.
///
/// Где живёт значение и как проверить, что оно живо, — в `.env.example`.
const String apiKeyEnvName = 'TYPIKON_API_KEY';

/// Приставка, с которой начинается всякий выданный ключ.
const String apiKeyPrefix = 'tk_';

/// Ключ из сырого значения — или `null`, если это не ключ.
///
/// Приставку проверяем у себя, и это не лишняя строгость: сервер на значение без
/// `tk_` не ругается, а молча откатывает клиента в анонимы. То есть опечатка в
/// `.env` обернулась бы не ошибкой, а шестьюдесятью запросами в час, и всплыла бы
/// через месяц по жалобе на «слишком часто».
String? normalizeApiKey(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.length <= apiKeyPrefix.length) return null;
  if (!value.startsWith(apiKeyPrefix)) return null;
  return value;
}

/// Откуда читается сырое значение. Подменяется тестами: `dotenv` в них не поднят,
/// а тащить его в проверку разбора незачем.
@visibleForTesting
String? Function() readRawApiKey = _fromDotEnv;

String? _fromDotEnv() => dotenv.isInitialized ? dotenv.maybeGet(apiKeyEnvName) : null;

bool _refused = false;

/// Ключ, которым стоит представляться сейчас. `null` — идём анонимом: либо его
/// нет в сборке, либо сервер его не признал. Для объяснения отказа по частоте
/// эти два случая неразличимы, и различать их незачем.
String? get apiKey => _refused ? null : normalizeApiKey(readRawApiKey());

/// Заголовок с ключом; пустая карта, если ключа нет.
///
/// Канал — `Authorization`, а не `X-Api-Key`: сессия пользователя едет заголовком
/// `Cookie`, столкновения нет, а сервер читает `X-Api-Key` только когда
/// `Authorization` пуст — держать ключ во втором канале значило бы зависеть от
/// того, что в первый никто никогда ничего не положит.
Map<String, String> apiKeyHeaders() {
  final key = apiKey;
  return key == null ? const {} : {'Authorization': 'Bearer $key'};
}

/// Сервер ключ не признал.
///
/// Дальше приложение живёт анонимом, а не показывает ошибку. Причина в том, что
/// ключ один на все установленные копии: отзови его кто-нибудь по недосмотру
/// вместе с чужими — и раздел погас бы разом у всех, до следующего выпуска.
/// Понижение квоты хуже, чем ничего, но несравнимо лучше погасшего раздела.
///
/// Обратная сторона названа в `.env.example`: мёртвый ключ выглядит как живой.
/// Поэтому о случившемся сообщаем на сервер — иначе узнать неоткуда.
void markApiKeyRefused(String reason) {
  if (_refused) return;
  _refused = true;
  reportCrash(ApiKeyRefused(reason), StackTrace.current, context: 'api-key');
}

/// Сервер отказался признать ключ приложения. Не падение, но знать надо.
class ApiKeyRefused implements Exception {
  const ApiKeyRefused(this.reason);

  final String reason;

  @override
  String toString() => 'ApiKeyRefused: $reason';
}

@visibleForTesting
void resetApiKeyState() {
  _refused = false;
  readRawApiKey = _fromDotEnv;
}

@visibleForTesting
bool get apiKeyRefused => _refused;
