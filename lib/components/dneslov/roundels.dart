import 'package:flutter/material.dart';
import 'package:typikon/dto/book.dart';

/// Строка текста книги: оплечный образ, если сервер прислал его с книгой, —
/// иначе значок по роду текста.
///
/// Раньше образ добывался отдельным запросом к dneslov.org по номеру памяти:
/// строка висела значком, пока приходил ответ, а с чужим сайтом это бывало
/// долго. Теперь адрес едет в ответе книги (`roundelUrl`), и сеть не нужна
/// вовсе: либо картинка, либо значок.
class Roundels extends StatelessWidget {
  final BookText item;

  const Roundels(context, {super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final roundelUrl = item.roundelUrl ?? "";
    return ListTile(
      leading: roundelUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                _absolute(roundelUrl),
                height: 32.0,
                width: 32.0,
                fit: BoxFit.cover,
                // Образ с чужого CDN: не загрузился — просто нет образа.
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            )
          : Icon(
              item.textType == "Historic" ? Icons.person_2_outlined : Icons.info_outline,
              color: Colors.grey,
              size: 32.0,
              semanticLabel: 'Text to announce in accessibility modes',
            ),
      title: Text(
          item.name,
          style: TextStyle(fontFamily: "OldStandard")),
      onTap: () =>
          Navigator.pushNamed(
              context, "/reading", arguments: item.id),
    );
  }

  /// Сервер присылает и полный адрес (https://cdn.dneslov.org/...), и путь без
  /// хоста (/roundels/...). Второй дополняем до полного.
  static String _absolute(String url) =>
      url.contains("://") ? url : "https://cdn.dneslov.org$url";
}
