class Sign {
  final String? id;
  final String? name;
  final String? source;
  final String? sign;
  final int? date;
  final int? month;

  const Sign({
    required this.id,
    required this.name,
    required this.source,
    required this.sign,
    required this.date,
    required this.month,
  });

  factory Sign.fromJson(Map<String, dynamic> json) {
    return Sign(
      name: json["name"],
      date: json["date"],
      month: json["month"],
      sign: json["sign"],
      source: json["source"],
      id: json["_id"],
    );
  }
}

class SignsList {
  final List<Sign> list;

  const SignsList({
    required this.list,
  });

  factory SignsList.fromJson(List<dynamic> json) {
    var list = json;
    List<Sign> items = List<Sign>.from(
        list
            .map((item) => Sign.fromJson(item))
            .toList()
    );
    return SignsList(
      list: items,
    );
  }
}