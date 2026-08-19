import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../apiMapper/report.dart';

/// Маленький попап у точки долгого тапа — единственный пункт, ведущий в
/// форму отправки. Двухшаговый флоу: долгий тап → попап → модалка.
Future<void> showWordReportMenu(
  BuildContext context,
  Offset globalPosition, {
  required String textId,
  required String contextText,
  required String word,
  required int wordIndex,
  int? paragraphIndex,
  int? chapter,
  int? verse,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & overlay.size,
  );
  final selected = await showMenu<bool>(
    context: context,
    position: position,
    items: const [
      PopupMenuItem(value: true, child: Text("Нашли ошибку? Сообщите об этом")),
    ],
  );
  if (selected == true && context.mounted) {
    showReportErrorSheet(
      context,
      textId: textId,
      contextText: contextText,
      word: word,
      wordIndex: wordIndex,
      paragraphIndex: paragraphIndex,
      chapter: chapter,
      verse: verse,
    );
  }
}

void showReportErrorSheet(
  BuildContext context, {
  required String textId,
  required String contextText,
  required String word,
  required int wordIndex,
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
        word: word,
        wordIndex: wordIndex,
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
  final String word;
  final int wordIndex;
  final int? paragraphIndex;
  final int? chapter;
  final int? verse;

  const _ReportErrorForm({
    required this.textId,
    required this.contextText,
    required this.word,
    required this.wordIndex,
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

  Map<String, dynamic> _buildSelection() {
    if (widget.chapter != null && widget.verse != null) {
      return {
        'type': 'verse',
        'chapter': widget.chapter,
        'verse': widget.verse,
        'verseText': widget.contextText,
        'word': widget.word,
        'wordIndex': widget.wordIndex,
      };
    }
    return {
      'type': 'paragraph',
      'paragraphIndex': widget.paragraphIndex,
      'paragraph': widget.contextText,
      'word': widget.word,
      'wordIndex': widget.wordIndex,
    };
  }

  Future<void> _submit() async {
    setState(() { _sending = true; });
    final ok = await submitErrorReport(
      textId: widget.textId,
      selection: _buildSelection(),
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
          Text("Нашли ошибку? Сообщите об этом", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(text: "Слово: "),
                TextSpan(text: widget.word, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.contextText,
            style: TextStyle(fontFamily: "OldStandard", color: Colors.grey[700]),
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
