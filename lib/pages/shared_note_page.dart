import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/v2/request.dart';
import '../apiMapper/v2/errors.dart';
import '../domain/companion.dart';

/// Both text notes and service notes use the same public link and reader.
class SharedNotePage extends StatefulWidget {
  final String token;
  const SharedNotePage({super.key, required this.token});
  @override
  State<SharedNotePage> createState() => _SharedNotePageState();
}

class _SharedNotePageState extends State<SharedNotePage> {
  late final Future<CompanionJson> note = load();
  Future<CompanionJson> load() async {
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(widget.token)) {
      throw StateError('Заметка недоступна.');
    }
    final r = await v2Get(v2Uri('/notes/shared/${widget.token}'));
    if (r.statusCode != 200) {
      throwV2Error(r, 'Заметка не опубликована или доступ отключён.');
    }
    return companionMap(companionMap(jsonDecode(r.body))['note']);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Личная заметка')),
    body: FutureBuilder<CompanionJson>(
      future: note,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final n = snapshot.data!, source = companionMap(n['source']);
        final href = source['href'] as String? ?? '';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${source['title'] ?? 'Заметка'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Личная заметка автора. Не является редакционным пояснением.',
            ),
            if ('${source['quote'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText('«${source['quote']}»'),
              ),
            const SizedBox(height: 16),
            SelectableText('${n['text']}'),
            if (href.startsWith('/') && !href.startsWith('//'))
              TextButton(
                onPressed: () => Navigator.pushNamed(context, href),
                child: const Text('Открыть исходное место'),
              ),
          ],
        );
      },
    ),
  );
}
