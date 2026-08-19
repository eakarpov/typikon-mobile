import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../apiMapper/report.dart';
import '../apiMapper/user_notes.dart';
import '../dto/user_note.dart';

Map<String, dynamic> _buildSelectionPayload({
  required String phrase,
  int? paragraphIndex,
  String? paragraph,
  int? chapter,
  int? verse,
  String? verseText,
}) {
  if (chapter != null && verse != null) {
    return {
      'type': 'verse',
      'chapter': chapter,
      'verse': verse,
      'verseText': verseText,
      'phrase': phrase,
      'wordIndex': 0,
    };
  }
  return {
    'type': 'paragraph',
    'paragraphIndex': paragraphIndex,
    'paragraph': paragraph,
    'phrase': phrase,
    'wordIndex': 0,
  };
}

void showReportErrorSheet(
  BuildContext context, {
  required String textId,
  required String contextText,
  required String phrase,
  int? paragraphIndex,
  int? chapter,
  int? verse,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReportErrorForm(
        textId: textId,
        contextText: contextText,
        phrase: phrase,
        paragraphIndex: paragraphIndex,
        chapter: chapter,
        verse: verse,
      ),
    ),
  );
}

class _ReportErrorForm extends StatefulWidget {
  final String textId;
  final String contextText;
  final String phrase;
  final int? paragraphIndex;
  final int? chapter;
  final int? verse;

  const _ReportErrorForm({
    required this.textId,
    required this.contextText,
    required this.phrase,
    this.paragraphIndex,
    this.chapter,
    this.verse,
  });

  @override
  State<_ReportErrorForm> createState() => _ReportErrorFormState();
}

class _ReportErrorFormState extends State<_ReportErrorForm> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _sending = true; });
    final ok = await submitErrorReport(
      textId: widget.textId,
      selection: _buildSelectionPayload(
        phrase: widget.phrase,
        paragraphIndex: widget.paragraphIndex,
        paragraph: widget.chapter == null ? widget.contextText : null,
        chapter: widget.chapter,
        verse: widget.verse,
        verseText: widget.chapter != null ? widget.contextText : null,
      ),
      correction: _controller.text,
    );
    if (!mounted) return;
    Navigator.pop(context);
    Fluttertoast.showToast(
      msg: ok ? "Спасибо! Сообщение отправлено" : "Не удалось отправить, попробуйте позже",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: ok ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Нашли ошибку? Сообщите об этом", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(text: "Выделено: "),
                TextSpan(text: widget.phrase, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "В чём ошибка / как правильно?",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? "Отправляем…" : "Отправить"),
            ),
          ),
        ],
      ),
    );
  }
}

void showAddNoteSheet(
  BuildContext context, {
  required String textId,
  required String contextText,
  required String phrase,
  int? paragraphIndex,
  int? chapter,
  int? verse,
  UserNote? existingNote,
  VoidCallback? onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AddNoteForm(
        textId: textId,
        contextText: contextText,
        phrase: phrase,
        paragraphIndex: paragraphIndex,
        chapter: chapter,
        verse: verse,
        existingNote: existingNote,
        onChanged: onChanged,
      ),
    ),
  );
}

class _AddNoteForm extends StatefulWidget {
  final String textId;
  final String contextText;
  final String phrase;
  final int? paragraphIndex;
  final int? chapter;
  final int? verse;
  final UserNote? existingNote;
  final VoidCallback? onChanged;

  const _AddNoteForm({
    required this.textId,
    required this.contextText,
    required this.phrase,
    this.paragraphIndex,
    this.chapter,
    this.verse,
    this.existingNote,
    this.onChanged,
  });

  @override
  State<_AddNoteForm> createState() => _AddNoteFormState();
}

class _AddNoteFormState extends State<_AddNoteForm> {
  late final TextEditingController _controller = TextEditingController(text: widget.existingNote?.note ?? "");
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() { _sending = true; });
    final existing = widget.existingNote;
    final ok = existing != null
        ? await editUserNote(existing.id, _controller.text)
        : (await submitUserNote(
            textId: widget.textId,
            selection: _buildSelectionPayload(
              phrase: widget.phrase,
              paragraphIndex: widget.paragraphIndex,
              paragraph: widget.chapter == null ? widget.contextText : null,
              chapter: widget.chapter,
              verse: widget.verse,
              verseText: widget.chapter != null ? widget.contextText : null,
            ),
            note: _controller.text,
          )) != null;
    if (!mounted) return;
    Navigator.pop(context);
    if (ok) widget.onChanged?.call();
    Fluttertoast.showToast(
      msg: ok ? "Заметка сохранена" : "Не удалось сохранить, попробуйте позже",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: ok ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _delete() async {
    final existing = widget.existingNote;
    if (existing == null) return;
    setState(() { _sending = true; });
    final ok = await removeUserNote(existing.id);
    if (!mounted) return;
    Navigator.pop(context);
    if (ok) widget.onChanged?.call();
    Fluttertoast.showToast(
      msg: ok ? "Заметка удалена" : "Не удалось удалить",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: ok ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingNote != null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? "Заметка" : "Новая заметка", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "«${widget.phrase}»",
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Ваша заметка",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isEdit) TextButton(
                onPressed: _sending ? null : _delete,
                child: const Text("Удалить"),
              ),
              TextButton(
                onPressed: _sending ? null : _save,
                child: Text(_sending ? "Сохраняем…" : "Сохранить"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
