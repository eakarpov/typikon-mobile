import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:typikon/dto/user_note.dart';
import '../apiMapper/user_notes.dart';

class NotesPage extends StatefulWidget {
  const NotesPage(context, {super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late Future<List<UserNote>> notes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      notes = getUserNotes();
    });
  }

  void _onDelete(UserNote note) async {
    final ok = await removeUserNote(note.id);
    if (!mounted) return;
    Fluttertoast.showToast(
      msg: ok ? "Заметка удалена" : "Не удалось удалить",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: ok ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
    if (ok) _load();
  }

  void _onOpen(UserNote note) {
    final arguments = note.selection.type == 'verse' && note.selection.chapter != null
        ? "${note.textId}#${note.selection.chapter}"
        : note.textId;
    Navigator.pushNamed(context, "/reading", arguments: arguments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Мои заметки", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<List<UserNote>>(
          future: notes,
          builder: (context, future) {
            if (future.hasError) {
              return Center(child: Text("Не удалось загрузить заметки"));
            }
            if (!future.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (future.data!.isEmpty) {
              return const Center(child: Text("Заметок пока нет."));
            }
            return ListView.builder(
              itemCount: future.data!.length,
              itemBuilder: (context, index) {
                final note = future.data![index];
                return ListTile(
                  title: Text(
                    note.textName ?? "Текст",
                    style: TextStyle(fontFamily: "OldStandard", color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("«${note.selection.phrase}»", style: const TextStyle(fontStyle: FontStyle.italic)),
                      Text(note.note),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _onDelete(note),
                  ),
                  onTap: () => _onOpen(note),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
