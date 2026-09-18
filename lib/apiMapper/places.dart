import 'dart:convert';

import 'package:typikon/api/places.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/dto/paged.dart';
import 'package:typikon/dto/place.dart';
import 'package:typikon/dto/place_mentions.dart';
import 'v2/errors.dart';

/// Разбор ответов о местах.
///
/// Отказы идут через `throwV2Error`, а не голым `Exception`: только так до
/// экрана доходят `ApiNotFoundException`, `ApiRateLimitedException` и прочие, а
/// с ними и внятное слово вместо «Не получены результаты».

Future<FacetedPage<PlaceSummary, PlaceFacets>> getPlaces({
  String? query,
  String? kind,
  bool scriptureOnly = false,
  int offset = 0,
}) async {
  final response = await fetchPlaces(
    query: query, kind: kind, scriptureOnly: scriptureOnly, offset: offset,
  );
  if (response.statusCode == 200) {
    return FacetedPage.fromJson<PlaceSummary, PlaceFacets>(
      jsonDecode(response.body),
      PlaceSummary.fromJson,
      PlaceFacets.fromJson,
    );
  }
  throwV2Error(response, "Не удалось открыть указатель мест");
}

Future<PlaceDetail> getPlace(String address) async {
  final response = await fetchPlace(address);
  if (response.statusCode == 200) {
    return PlaceDetail.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить место");
}

Future<PlaceMentions> getPlaceMentions(String address) async {
  final response = await fetchPlaceMentions(address);
  if (response.statusCode == 200) {
    return PlaceMentions.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить упоминания места");
}

Future<Paged<PlaceVerse>> getPlaceScripture(
  String address, {
  String? book,
  int offset = 0,
}) async {
  final response = await fetchPlaceScripture(address, book: book, offset: offset);
  if (response.statusCode == 200) {
    return Paged.fromJson<PlaceVerse>(jsonDecode(response.body), PlaceVerse.fromJson);
  }
  throwV2Error(response, "Не удалось загрузить стихи");
}

Future<List<TextPlaceRef>> getTextPlaces(String textId) async {
  final response = await fetchTextPlaces(textId);
  if (response.statusCode == 200) {
    return Paged.fromJson<TextPlaceRef>(jsonDecode(response.body), TextPlaceRef.fromJson).items;
  }
  throwV2Error(response, "Не удалось загрузить места текста");
}

Future<List<ChapterPlace>> getChapterPlaces(String canonId, int chapter) async {
  final response = await fetchChapterPlaces(canonId, chapter);
  if (response.statusCode == 200) {
    return Paged.fromJson<ChapterPlace>(jsonDecode(response.body), ChapterPlace.fromJson).items;
  }
  throwV2Error(response, "Не удалось загрузить места главы");
}
