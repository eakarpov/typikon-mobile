library;

/// Молитвы с именами из помянника — ответ личной ручки `/api/v2/prayer-text`.
///
/// Сервер сам берёт имена из своего помянника: клиент шлёт только «для кого»
/// (о живых / об усопших), стиль и род молящегося, а в ответе — готовые тексты,
/// где имена уже подставлены. Разбор tolerant, как у ордо
/// (`lib/dto/ordo.dart`): руку правят чаще приложения, и незнакомое поле
/// обязано пройти мимо, а не упасть.

/// Одна молитва. [title] у кратких молитвословных текстов может не быть.
class NamedPrayer {
  final String id;
  final String? title;
  final String text;

  const NamedPrayer({this.id = "", this.title, this.text = ""});

  factory NamedPrayer.fromJson(Map<String, dynamic> json) => NamedPrayer(
        id: json["id"] is String ? json["id"] as String : "",
        title: json["title"] is String ? json["title"] as String : null,
        text: json["text"] is String ? json["text"] as String : "",
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        if (title != null) "title": title,
        "text": text,
      };
}

/// Ответ ручки целиком. `for` — служебное слово, поле зовётся [forKind].
class PrayerText {
  final String forKind;
  final String style;
  final String lang;
  final String gender;
  final List<NamedPrayer> prayers;

  const PrayerText({
    this.forKind = "",
    this.style = "",
    this.lang = "",
    this.gender = "",
    this.prayers = const <NamedPrayer>[],
  });

  factory PrayerText.fromJson(Map<String, dynamic> json) => PrayerText(
        forKind: json["for"] is String ? json["for"] as String : "",
        style: json["style"] is String ? json["style"] as String : "",
        lang: json["lang"] is String ? json["lang"] as String : "",
        gender: json["gender"] is String ? json["gender"] as String : "",
        prayers: json["prayers"] is List
            ? (json["prayers"] as List)
                .whereType<Map>()
                .map((row) => NamedPrayer.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <NamedPrayer>[],
      );
}
