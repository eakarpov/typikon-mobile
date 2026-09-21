import 'package:flutter/material.dart';

/// Досье: раздел и строка в нём.
///
/// Досье в приложении три — святого, места и лица в помяннике, — и раздел со
/// строкой были в них скопированы слово в слово. Отсюда же и расхождения:
/// у одного отступ сверху 20 точек, у другого 16, и заметить это можно было,
/// только открыв оба экрана подряд.
///
/// Заголовок раздела набран киноварью (`colorScheme.primary`) и тем же
/// шрифтом, что и текст, — раздел досье не заголовок страницы, а помета на
/// поле: он отделяет, но не кричит.
class DossierSection extends StatelessWidget {
  const DossierSection({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: "OldStandard",
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Строка досье: имя и пояснение под ним, иногда с переходом.
class DossierLine extends StatelessWidget {
  const DossierLine({
    super.key,
    required this.title,
    this.subtitle = "",
    this.onTap,
  });

  final String title;
  final String subtitle;

  /// Есть ли куда вести. Строки досье по большей части никуда не ведут, и
  /// ведущая от неведущей отличается цветом: подчёркнутая или крашеная строка
  /// без перехода обещала бы страницу, которой нет.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: "OldStandard",
            color: onTap == null ? null : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
        child: body,
      );
    }

    // По чему нажимают — то и должно быть не меньше 48 точек. Однострочная
    // ведущая строка с отступом в 4 точки давала около тридцати, то есть
    // промахнуться по ней было легче, чем попасть.
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
          child: Align(alignment: Alignment.centerLeft, child: body),
        ),
      ),
    );
  }
}
