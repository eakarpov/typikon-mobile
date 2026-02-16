import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/saints.dart';
import "package:typikon/dto/saint.dart";
import "package:typikon/dto/text.dart";
import 'package:url_launcher/url_launcher_string.dart';

class ResourcesPage extends StatefulWidget {

  const ResourcesPage(context, {super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  late Future<Saint> saint;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Полезные ресурсы"),
        ),
        body: Container(
          color: const Color(0xffffffff),
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Expanded(
              child: ListView.separated(
                  itemCount: 2,
                  itemBuilder: (BuildContext ctxt, int Index) {
                    return SizedBox(
                      height: Index == 0 ? 400 : 100,
                      child: ListView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: Index == 0 ? 5 : 1,
                          itemBuilder: (context, index) {
                            var itemName = "";
                            var itemLink = "";
                            var itemDescription = "";
                            switch (index) {
                              case 0:
                                if (Index == 0) {
                                  itemName = "Днеслов";
                                  itemDescription = "Православный календарь";
                                  itemLink = "https://dneslov.org/";
                                } else {
                                  itemName = "Наш портал";
                                  itemDescription = "Список памятей со знаком";
                                  itemLink = "/signs";
                                }
                                break;
                              case 1:
                                itemName = "Осанна";
                                itemDescription =
                                "Портал богослужебной и святоотеческой литературы";
                                itemLink = "https://osanna.russportal.ru/";
                                break;
                              case 2:
                                itemName = "ЖК Уставщик";
                                itemDescription =
                                "Собрание редких и новых богослужебных текстов";
                                itemLink = "https://ustavschik.livejournal.com/";
                                break;
                              case 3:
                                itemName = "znamen.ru";
                                itemDescription = "Фонд знаменных песнопений";
                                itemLink = "http://znamen.ru";
                                break;
                              case 4:
                                itemName = "Фонд Scripta Bulgarica";
                                itemDescription =
                                "Отекстованное собрание балканских архивов";
                                itemLink =
                                "http://scripta-bulgarica.eu/bg/manuscript";
                                break;
                              case 5:
                                itemName = "lib-fond";
                                itemDescription =
                                "Собрание рукописей и старопечатных книг";
                                itemLink = "https://lib-fond.ru/";
                                break;
                              default:
                                break;
                            }
                            return ListTile(
                              title: Text(
                                  itemName,
                                  style: TextStyle(fontFamily: "OldStandard")),
                              subtitle: Text(
                                  itemDescription,
                                  style: TextStyle(fontFamily: "OldStandard", color: Colors.grey)
                              ),
                              onTap: () {
                                if (Index == 0) {
                                  launchUrlString(itemLink);
                                } else {
                                  Navigator.of(context).pushNamed(itemLink);
                                }
                              },
                            );
                          }
                      ),
                    );
                  },
                  separatorBuilder: (context, build)=>Divider(
                    thickness: 1,
                    color: Color(0xff002540).withOpacity(.1),
                  ),
                ),
            ),
        ),
      ),
    );
  }
}