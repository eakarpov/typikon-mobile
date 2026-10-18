import 'package:flutter/material.dart';

import '../dto/prayer_text.dart';
import '../store/psalter_prayers.dart';
import '../utils/reading_style.dart';

/// Тексты плашек — одним местом: их сверяют тесты и локализация их не ждёт.
const String namedPrayersStaleNotice =
    "Имена не обновлены (нет сети); показан сохранённый состав.";
const String namedPrayersUnavailableNotice =
    "Молитвы с именами недоступны без сети.";
const String namedPrayersSignInNotice =
    "Войдите, чтобы читать с именами из помянника.";

/// Блок поминальных молитв: вставляется в чтение после славы кафизмы
/// (в «подряд» — после границы кафизмы целиком).
///
/// Три честных состояния, и ни одно не притворяется молитвой:
/// не вошли — [namedPrayersSignInNotice], кафизма читается как обычная;
/// сети нет и снимка нет — [namedPrayersUnavailableNotice]; состав протух —
/// [namedPrayersStaleNotice] над показанным снимком. Молитвы идут двумя
/// рядами: «О усопших:» (после «Слава») и «О живых:» (после «И ныне»).
class NamedPrayerBlock extends StatelessWidget {
  const NamedPrayerBlock(this.prayers, {super.key, this.showNotice = true});

  final PsalterNamedPrayers prayers;

  /// Плашку показывает только первый блок на экране: повторять «имена не
  /// обновлены» после каждой из трёх слав — значит задушить этим самым славы.
  final bool showNotice;

  @override
  Widget build(BuildContext context) {
    if (prayers.signInNeeded) {
      return showNotice ? const _Notice(namedPrayersSignInNotice) : const SizedBox.shrink();
    }
    if (prayers.unavailable) {
      return showNotice ? const _Notice(namedPrayersUnavailableNotice) : const SizedBox.shrink();
    }
    if (!prayers.hasPrayers) return const SizedBox.shrink();

    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (prayers.stale && showNotice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(namedPrayersStaleNotice, style: small),
            ),
          _Group("О усопших:", prayers.departed),
          _Group("О живых:", prayers.living),
        ],
      ),
    );
  }
}

/// Один ряд блока: курсивный заголовок «О усопших:» и тексты молитв.
/// Заголовок ряда без текстов не показываем: вывеска без молитвы — хуже
/// её отсутствия.
class _Group extends StatelessWidget {
  const _Group(this.heading, this.prayers);

  final String heading;
  final List<NamedPrayer> prayers;

  @override
  Widget build(BuildContext context) {
    if (prayers.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Text(
              heading,
              style: TextStyle(
                fontFamily: "OldStandard",
                fontSize: readingFontSize(context) * 0.9,
                fontStyle: FontStyle.italic,
                color: primary,
              ),
            ),
          ),
          for (final prayer in prayers) ...<Widget>[
            if ((prayer.title ?? "").isNotEmpty)
              Text(
                prayer.title!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ReadingText(prayer.text, churchSlavonic: true),
          ],
        ],
      ),
    );
  }
}

/// Короткая плашка-предупреждение вместо блока молитв.
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontSize: readingFontSize(context) * 0.9,
            fontStyle: FontStyle.italic,
            color: readingTextColor(context),
          ),
        ),
      ),
    );
  }
}
