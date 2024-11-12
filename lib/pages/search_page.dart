import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/dto/search.dart';
import "package:typikon/apiMapper/search.dart";

class SearchPage extends StatefulWidget {
  const SearchPage(context, {super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late Future<List<SearchBookText>> results;
  String searchValue = "";

  @override
  void initState() {
    super.initState();
    results = getSearchResult(null);
  }

  void updateResults() {
    print(searchValue);
    // results = new Future<List<SearchBookText>>.error([]);
    setState(() {
      results = getSearchResult(searchValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Поиск по названию текста")
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchValue = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                        labelText: 'Поиск',
                        suffixIcon: Icon(Icons.search)
                    ),
                  ),
                ),
                TextButton(
                  onPressed: updateResults,
                  child: Text('OK'),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: FutureBuilder(
              builder: (context, AsyncSnapshot<List<SearchBookText>> snapshot) {
                print(snapshot.hasData);
                print(snapshot.connectionState);
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData) {
                  return Center(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          // leading: CircleAvatar(
                          //   backgroundImage: NetworkImage(
                          //       '${snapshot.data?[index].imageUrl}'),
                          // ),
                          title: Text('${snapshot.data?[index].name}'),
                          onTap: () => {
                            Navigator.pushNamed(context, "/reading", arguments: snapshot.data?[index].id)
                          },
                          // subtitle: Text(
                          //     'Score: ${snapshot.data?[index].score}'),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return Divider();
                      },
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text('Ошибка при получении'));
                }
                return Center(child: CircularProgressIndicator());
              },
              future: results,
            ),
          ),
        ],
      ),
    );
  }
}