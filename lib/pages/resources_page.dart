import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Чужие собрания, которыми пользуемся сами.
///
/// Здесь только внешние сайты, и это правило. Прежде седьмой строкой стоял
/// «Наш портал» — ссылка на свой же раздел знаков Типикона; найти его там было
/// нельзя, и он переехал в «Пособия», к прочим своим разделам.
///
/// Перечень — данными, а не `switch` по номеру строки: прежний вид требовал
/// держать в согласии `itemCount`, номера ветвей и условие `index <= 5`,
/// решавшее, внешняя ссылка или внутренняя.
class Resource {
  final String name;
  final String description;
  final String url;

  const Resource(this.name, this.description, this.url);
}

const List<Resource> resources = <Resource>[
  Resource("Днеслов", "Православный календарь", "https://dneslov.org/"),
  Resource("Осанна", "Портал богослужебной и святоотеческой литературы",
      "https://osanna.russportal.ru/"),
  Resource("ЖК Уставщик", "Собрание редких и новых богослужебных текстов",
      "https://ustavschik.livejournal.com/"),
  Resource("znamen.ru", "Фонд знаменных песнопений", "http://znamen.ru"),
  Resource("Фонд Scripta Bulgarica", "Отекстованное собрание балканских архивов",
      "http://scripta-bulgarica.eu/bg/manuscript"),
  Resource("lib-fond", "Собрание рукописей и старопечатных книг",
      "https://lib-fond.ru/"),
];

class ResourcesPage extends StatelessWidget {
  const ResourcesPage(context, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Полезные ресурсы",
            style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: ListView.builder(
        itemCount: resources.length,
        itemBuilder: (context, index) {
          final resource = resources[index];
          return ListTile(
            title: Text(resource.name,
                style: const TextStyle(fontFamily: "OldStandard")),
            subtitle: Text(
              resource.description,
              style: const TextStyle(
                  fontFamily: "OldStandard", color: Colors.grey),
            ),
            trailing: const Icon(Icons.open_in_new, size: 18.0),
            onTap: () => launchUrlString(resource.url),
          );
        },
      ),
    );
  }
}
