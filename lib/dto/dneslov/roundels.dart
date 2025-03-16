class DneslovRoundelsDItem {
  final String? roundelable_name;
  final String? url;
  final String? uid;

  const DneslovRoundelsDItem({
    required this.roundelable_name,
    required this.url,
    required this.uid,
  });

  factory DneslovRoundelsDItem.fromJson(Map<String, dynamic> json) {
    return DneslovRoundelsDItem(
      roundelable_name: json["roundelable_name"],
      url: json["url"],
      uid: json["id"],
    );
  }
}

class DneslovRoundelsListD {
  final List<DneslovRoundelsDItem> list;

  const DneslovRoundelsListD({
    required this.list,
  });

  factory DneslovRoundelsListD.fromJson(dynamic json) {
    var list = json;
    List<DneslovRoundelsDItem> items = List<DneslovRoundelsDItem>.from(
        list
            .map((item) => DneslovRoundelsDItem.fromJson(item))
            .toList()
    );
    return DneslovRoundelsListD(
      list: items,
    );
  }
}