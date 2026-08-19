import 'package:flutter/material.dart';

/// Зеркало бекендового src/utils/signs.ts — подписи и глифы уставных
/// знаков месяцеслова Типикона.
const Map<String, String> signLabels = {
  'NO_SIGN': 'Без знака',
  'HALLELUJAH': 'Аллилуйная',
  'SIX_STICHERA': 'Шестеричная',
  'DOXOLOGIC': 'Славословная',
  'POLYELEOS': 'Полиелейная',
  'VIGIL': 'Бденная',
  'GREAT_VIGIL': 'Бдение (двунадесятый праздник)',
};

class SignGlyph {
  final String glyph;
  final Color color;

  const SignGlyph(this.glyph, this.color);
}

// Юникод-символы U+1F540..U+1F543 — те же, что использует источник
// azbyka.ru и бекендовый импортёр. NO_SIGN и HALLELUJAH глифа не имеют.
final Map<String, SignGlyph> signGlyphs = {
  'GREAT_VIGIL': const SignGlyph('\u{1F540}', Colors.red),
  'VIGIL': const SignGlyph('\u{1F541}', Colors.red),
  'POLYELEOS': const SignGlyph('\u{1F542}', Colors.red),
  'DOXOLOGIC': const SignGlyph('\u{1F543}', Colors.red),
  'SIX_STICHERA': const SignGlyph('\u{1F543}', Colors.black),
};

String signLabel(String sign) => signLabels[sign] ?? sign;
SignGlyph? signGlyph(String sign) => signGlyphs[sign];
