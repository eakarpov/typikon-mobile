import '../dto/reference.dart';

// Имена грамматических ячеек словаря.
//
// Сервер отдаёт адреса — `sgNom`, `duGenLoc`, `aorPl3`, `partPastPass`, — и это
// правильно: адрес не зависит от языка, которым мы его подпишем. Подписи наши,
// и всякий незнакомый адрес показывается **как есть**: заведут в словаре новую
// ячейку — читатель увидит её непереведённой, но увидит.

const Map<String, String> _slots = {
  // Существительное
  "sgNom": "ед. им.",
  "sgAcc": "ед. вин.",
  "sgGen": "ед. род.",
  "sgDat": "ед. дат.",
  "sgLoc": "ед. мест.",
  "sgIns": "ед. твор.",
  "sgVoc": "ед. зват.",
  "plNom": "мн. им.",
  "plAcc": "мн. вин.",
  "plGen": "мн. род.",
  "plDat": "мн. дат.",
  "plLoc": "мн. мест.",
  "plIns": "мн. твор.",
  "duNomAcc": "дв. им.-вин.",
  "duGenLoc": "дв. род.-мест.",
  "duDatIns": "дв. дат.-твор.",

  // Прилагательное
  "sgMNomAcc": "ед. м. им.-вин.",
  "sgNNomAcc": "ед. ср. им.-вин.",
  "sgMNGen": "ед. м./ср. род.",
  "sgMAcc": "ед. м. вин.",
  "sgMNDat": "ед. м./ср. дат.",
  "sgMNLoc": "ед. м./ср. мест.",
  "sgMNIns": "ед. м./ср. твор.",
  "sgFNom": "ед. ж. им.",
  "sgFAcc": "ед. ж. вин.",
  "sgFGen": "ед. ж. род.",
  "sgFDatLoc": "ед. ж. дат.-мест.",
  "sgFIns": "ед. ж. твор.",
  "plMNom": "мн. м. им.",
  "plMAccFNomAcc": "мн. м. вин., ж. им.-вин.",
  "plNNomAcc": "мн. ср. им.-вин.",
  "plGenLoc": "мн. род.-мест.",
  "duMNomAcc": "дв. м. им.-вин.",
  "duNFNomAcc": "дв. ср./ж. им.-вин.",
  "sgMVoc": "ед. м. зват.",

  // Глагол
  "presSg1": "наст. я",
  "presSg2": "наст. ты",
  "presSg3": "наст. он",
  "presPl1": "наст. мы",
  "presPl2": "наст. вы",
  "presPl3": "наст. они",
  "presDu1": "наст. дв. мы",
  "presDu23": "наст. дв. вы, они",
  "impSg23": "повел. ты",
  "impPl2": "повел. вы",
  "impPl1": "повел. мы",
  "impDu1": "повел. дв. мы",
  "impDu2": "повел. дв. вы",
  "imperfSg1": "имперф. я",
  "imperfSg23": "имперф. ты, он",
  "imperfPl1": "имперф. мы",
  "imperfPl2": "имперф. вы",
  "imperfPl3": "имперф. они",
  "imperfDu1": "имперф. дв. мы",
  "imperfDu23": "имперф. дв. вы, они",
  "aorSg1": "аорист я",
  "aorSg23": "аорист ты, он",
  "aorPl1": "аорист мы",
  "aorPl2": "аорист вы",
  "aorPl3": "аорист они",
  "aorDu1": "аорист дв. мы",
  "aorDu23": "аорист дв. вы, они",
  "inf": "неопределённая",
  "partPerf": "прич. перфекта",
  "partPresActSg": "прич. наст. действ. ед.",
  "partPresAct": "прич. наст. действ.",
  "partPresPass": "прич. наст. страд.",
  "partPastAct": "прич. прош. действ.",
  "partPastPass": "прич. прош. страд.",
};

String slotLabel(String slot) => _slots[slot] ?? slot;

const Map<String, String> _partsOfSpeech = {
  "noun": "существительное",
  "adjective": "прилагательное",
  "verb": "глагол",
  "other": "",
};

String partOfSpeechLabel(String pos) => _partsOfSpeech[pos] ?? pos;

/// Заголовок парадигмы.
///
/// У причастия он свой — имя формы и основа: причастия глагола склоняются
/// отдельными парадигмами, а не строкой в спряжении, и без заголовка четыре
/// таблицы подряд слились бы в одну.
String paradigmTitle(LexemeParadigm paradigm) {
  final title = paradigm.title;
  switch (paradigm.kind) {
    case "noun":
      return "Склонение";
    case "adjective-brev":
      return "Краткая форма";
    case "adjective-plen":
      return "Полная форма";
    case "verb":
      return "Спряжение";
    case "participle-brev":
      return title == null ? "Причастие, краткая форма" : "$title — краткая форма";
    case "participle-plen":
      return title == null ? "Причастие, полная форма" : "$title — полная форма";
    default:
      return title ?? paradigm.kind;
  }
}
