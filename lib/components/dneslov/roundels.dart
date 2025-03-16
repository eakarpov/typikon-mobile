import 'package:flutter/material.dart';
import 'package:typikon/apiMapper/dneslov/images.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/dto/dneslov/roundels.dart';

class Roundels extends StatefulWidget {
  final BookText item;

  const Roundels(context, {super.key, required this.item});

  @override
  State<Roundels> createState() => _RoundelsState();
}

class _RoundelsState extends State<Roundels> {
  late Future<DneslovRoundelsListD> dneslovImages;

  @override
  void initState() {
    super.initState();
    dneslovImages = fetchDneslovRoundelsD(widget.item!.dneslovId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DneslovRoundelsListD>(
        future: dneslovImages,
        builder: (context, future) {
          if (future.hasData) {
            DneslovRoundelsDItem first = future.data!.list!.first;
            String imageUrl = first != null ? first.url??"" : "";
            String rightImageUrl = imageUrl.contains("://") ? imageUrl : "https://cdn.dneslov.org$imageUrl";
            return Container(
              child: ListTile(
                leading: Image.network(
                  rightImageUrl,
                  height: 32.0,
                  width: 32.0,
                ),
                title: Text(
                    widget.item.name,
                    style: TextStyle(fontFamily: "OldStandard")),
                onTap: () =>
                {
                  Navigator.pushNamed(
                      context, "/reading", arguments: widget.item.id)
                },
              ),
            );
          }
          return Container(
            child: ListTile(
              leading: Icon(
                widget.item.textType == "Historic" ? Icons.person_2_outlined : Icons.info_outline,
                color: Colors.grey,
                size: 32.0,
                semanticLabel: 'Text to announce in accessibility modes',
              ),
              title: Text(
                  widget.item.name,
                  style: TextStyle(fontFamily: "OldStandard")),
              onTap: () =>
              {
                Navigator.pushNamed(
                    context, "/reading", arguments: widget.item.id)
              },
            ),
          );
        }
    );
  }
}