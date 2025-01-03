import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:typikon/apiMapper/places.dart';
import "package:typikon/dto/place.dart";

class PlacePage extends StatefulWidget {
  final String id;

  const PlacePage(context, {super.key, required this.id});

  @override
  State<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  late Future<PlaceInfo> place;

  @override
  void initState() {
    super.initState();
    place = getPlace(widget.id);
  }

  void onClick(String? url) {
    if (url is String) {
      Uri myUrl = Uri.parse(url);
      launchUrl(myUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PlaceInfo>(
          future: place,
          builder: (context, future) {
            if (future.hasData) {
              String name = future.data!.name??"";
              return Text(name);
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<PlaceInfo>(
          future: place,
          builder: (context, future) {
            if (future.hasData) {
              return Container(
                child: Column(
                  children: [
                    Text("Название: ${future.data!.name}"),
                    Text("Описание: ${future.data!.description}"),
                    Text("Долгота: ${future.data!.longitude}"),
                    Text("Широта: ${future.data!.latitude}"),
                    Expanded(child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: future.data!.links.length,
                      itemBuilder: (context, index) {
                        final item = future.data!.links[index];
                        return Container(
                          child: ListTile(
                            title: Text(item.text??""),
                            onTap: () => onClick(item.url),
                          ),
                        );
                      },
                    ),)
                  ],
                ),
              );
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return Container(
              color: const Color(0xffffffff),
              width: double.infinity,
              height: double.infinity,
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