class DneslovImageDItem {
  final String description;
  final String thumb_url;
  final String title;
  final String type;
  final String uid;
  final String url;

  const DneslovImageDItem({
    required this.description,
    required this.thumb_url,
    required this.title,
    required this.type,
    required this.uid,
    required this.url,
  });

  factory DneslovImageDItem.fromJson(Map<String, dynamic> json) {
    return DneslovImageDItem(
      title: json["title"],
      description: json["description"],
      type: json["type"],
      thumb_url: json["thumb_url"],
      url: json["url"],
      uid: json["uid"],
    );
  }
}

class DneslovImageListD {
  final List<DneslovImageDItem> list;

  const DneslovImageListD({
    required this.list,
  });

  factory DneslovImageListD.fromJson(dynamic json) {
    var list = json;
    print(list);
    List<DneslovImageDItem> items = List<DneslovImageDItem>.from(
        list
            .map((item) => DneslovImageDItem.fromJson(item))
            .toList()
    );
    return DneslovImageListD(
      list: items,
    );
  }
}