import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/apiMapper/signs.dart';
import 'package:typikon/dto/library.dart';
import 'package:typikon/dto/signs.dart';

import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';

class SignsPage extends StatefulWidget {
  const SignsPage(context, {super.key});

  @override
  State<SignsPage> createState() => _SignsPageState();
}

class _SignsPageState extends State<SignsPage> {
  late Future<SignsList> signsList;

  @override
  void initState() {
    super.initState();
    signsList = getSigns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Список памятей", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<SignsList>(
          future: signsList,
          builder: (context, future) {
            if (future.hasData) {
              List<Sign> list = future.data!.list;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                    child: ListTile(
                      title: Text(item.name??"test"),
                      subtitle: Text(item.sign??"test"),
                      onTap: () => {
                        Navigator.pushNamed(context, "/sign", arguments: item.id)
                      },
                    ),
                  );
                },
              );
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return Container(
              color: const Color(0xffffffff),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}