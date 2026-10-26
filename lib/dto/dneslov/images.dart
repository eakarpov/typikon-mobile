/// Images are loaded directly from Dneslov's CDN, never from arbitrary hosts.
String? dneslovImageUrl(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return null;
  final resolved = Uri.parse('https://cdn.dneslov.org').resolveUri(uri);
  if (resolved.host != 'cdn.dneslov.org' ||
      (resolved.scheme != 'http' && resolved.scheme != 'https') ||
      resolved.userInfo.isNotEmpty) {
    return null;
  }
  return resolved.replace(scheme: 'https').toString();
}

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
    final url = dneslovImageUrl(json['url']) ?? '';
    return DneslovImageDItem(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      thumb_url: dneslovImageUrl(json['thumb_url'] ?? json['thumbUrl']) ?? url,
      url: url,
      uid: json['uid']?.toString() ?? url,
    );
  }
}

class DneslovImageListD {
  final List<DneslovImageDItem> list;
  const DneslovImageListD({required this.list});
  factory DneslovImageListD.fromJson(dynamic json) {
    final rows = json is List
        ? json
        : (json is Map && json['list'] is List ? json['list'] as List : null);
    if (rows == null) {
      throw const FormatException('Неверный список изображений');
    }
    final seen = <String>{};
    return DneslovImageListD(
      list: rows
          .whereType<Map>()
          .map((r) => DneslovImageDItem.fromJson(Map<String, dynamic>.from(r)))
          .where((r) => r.url.isNotEmpty && seen.add(r.url))
          .toList(),
    );
  }
}
