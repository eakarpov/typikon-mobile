class NoteSelection {
  final String type; // 'paragraph' | 'verse'
  final String phrase;
  final int? paragraphIndex;
  final String? paragraph;
  final int? chapter;
  final int? verse;
  final String? verseText;

  const NoteSelection({
    required this.type,
    required this.phrase,
    this.paragraphIndex,
    this.paragraph,
    this.chapter,
    this.verse,
    this.verseText,
  });

  factory NoteSelection.fromJson(Map<String, dynamic> json) {
    return NoteSelection(
      type: json['type'] ?? 'paragraph',
      phrase: json['phrase'] ?? '',
      paragraphIndex: json['paragraphIndex'],
      paragraph: json['paragraph'],
      chapter: json['chapter'],
      verse: json['verse'],
      verseText: json['verseText'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'phrase': phrase,
    if (paragraphIndex != null) 'paragraphIndex': paragraphIndex,
    if (paragraph != null) 'paragraph': paragraph,
    if (chapter != null) 'chapter': chapter,
    if (verse != null) 'verse': verse,
    if (verseText != null) 'verseText': verseText,
  };
}

class UserNote {
  final String id;
  final String textId;
  final NoteSelection selection;
  final String note;
  final String? textName; // только в списке "все заметки" (профиль)

  const UserNote({
    required this.id,
    required this.textId,
    required this.selection,
    required this.note,
    this.textName,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      id: json['id'] ?? '',
      textId: json['textId'] ?? '',
      selection: NoteSelection.fromJson(json['selection'] ?? {}),
      note: json['note'] ?? '',
      textName: json['textName'],
    );
  }
}
