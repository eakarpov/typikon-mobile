import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/constants.dart';
import '../domain/companion.dart';
import '../store/companion.dart';
import 'api_error_view.dart' show failureMessage;

/// Personal writing stays separate from editorial explanations and progress.
class CompanionNotes extends StatefulWidget {
  final CompanionRepository repository;
  final CompanionJson service, node, selection;
  const CompanionNotes({
    super.key,
    required this.repository,
    required this.service,
    required this.node,
    required this.selection,
  });
  @override
  State<CompanionNotes> createState() => _CompanionNotesState();
}

class _CompanionNotesState extends State<CompanionNotes> {
  final text = TextEditingController();
  List<CompanionJson> notes = [];
  CompanionJson? editing;
  bool loading = false, loaded = false, saving = false;
  String error = '';
  String draftId = newId();
  static String newId() => List.generate(
    12,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  String get shareUrl => editing?['shareToken'] == null
      ? ''
      : '$apiBaseUrl/notes/shared/${editing!['shareToken']}';

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (loaded || loading || widget.repository.userId == null) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final query = Uri(
        queryParameters: {
          'sessionKey': '${widget.service['sessionKey']}',
          'nodeId': '${widget.node['id']}',
        },
      ).query;
      final data = companionMap(
        await widget.repository.request('GET', '/notes?$query', personal: true),
      );
      if (data['userId'] != widget.repository.userId) {
        throw StateError('Вход изменился.');
      }
      if (mounted) {
        setState(() {
          notes = companionList(data['notes']);
          loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = failureMessage(e, 'Не удалось загрузить заметки'),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save(bool published) async {
    if (saving || text.text.trim().isEmpty) return;
    if (published && editing?['published'] != true) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Опубликовать заметку?'),
          content: const Text(
            'Любой получатель ссылки увидит текст этой заметки и место службы. Остальные ваши записи останутся приватными.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Опубликовать'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final data = companionMap(
        await widget.repository.request(
          'POST',
          '/notes',
          personal: true,
          body: {
            'expectedUserId': widget.repository.userId,
            'id': editing?['id'] ?? draftId,
            'expectedRevision': editing?['revision'] ?? 0,
            'expectedSharingRevision': editing?['sharingRevision'] ?? 0,
            'sessionKey': widget.service['sessionKey'],
            'nodeId': widget.node['id'],
            'contentHash': widget.node['contentHash'],
            'title': widget.service['title'],
            'nodeTitle': widget.node['title'],
            'selection': widget.selection,
            'text': text.text.trim(),
            'published': published,
          },
        ),
      );
      if (data['userId'] != widget.repository.userId) {
        throw StateError('Вход изменился.');
      }
      if (!mounted) return;
      final note = companionMap(data['note']);
      setState(() {
        editing = note;
        notes = [note, ...notes.where((n) => n['id'] != note['id'])];
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = failureMessage(
            e,
            'Не удалось сохранить заметку. Текст остаётся в редакторе',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Мои заметки к этому месту'),
    onExpansionChanged: (open) {
      if (open) load();
    },
    childrenPadding: const EdgeInsets.all(12),
    children: widget.repository.userId == null
        ? [
            const Text('Для сохранения личных заметок войдите в аккаунт.'),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Войти'),
            ),
          ]
        : [
            if (loading) const LinearProgressIndicator(),
            TextButton(
              onPressed: loading || saving
                  ? null
                  : () {
                      loaded = false;
                      load();
                    },
              child: const Text('Обновить список заметок'),
            ),
            for (final n in notes)
              ListTile(
                title: Text('${n['text']}'),
                subtitle: Text(
                  '${n['published'] == true ? 'Доступна по ссылке' : 'Приватная'}${n['contentHash'] != widget.node['contentHash'] ? ' · текст части изменился' : ''}',
                ),
                enabled: !saving,
                onTap: () => setState(() {
                  editing = n;
                  text.text = '${n['text']}';
                }),
              ),
            if (loaded && notes.isEmpty)
              const Text('К этой части пока нет личных заметок.'),
            TextField(
              controller: text,
              enabled: !saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 10000,
              decoration: InputDecoration(
                labelText: editing == null
                    ? 'Новая приватная заметка'
                    : 'Редактировать заметку',
              ),
            ),
            const Text(
              'Это личная запись автора, а не редакционное пояснение. Публикация открывает доступ любому получателю ссылки.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => save(editing?['published'] == true),
                  child: Text(
                    editing?['published'] == true
                        ? 'Сохранить изменения'
                        : 'Сохранить приватно',
                  ),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () => save(editing?['published'] != true),
                  child: Text(
                    editing?['published'] == true
                        ? 'Отключить доступ по ссылке'
                        : 'Опубликовать по ссылке',
                  ),
                ),
                if (editing != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            editing = null;
                            draftId = newId();
                            text.clear();
                          }),
                    child: const Text('Новая заметка'),
                  ),
              ],
            ),
            if (shareUrl.isNotEmpty) ...[
              SelectableText(shareUrl),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                    },
                    child: const Text('Скопировать ссылку'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await SharePlus.instance.share(
                        ShareParams(text: shareUrl),
                      );
                    },
                    child: const Text('Поделиться'),
                  ),
                ],
              ),
            ],
            if (error.isNotEmpty) Text(error),
            if (error.isNotEmpty && !loaded)
              TextButton(
                onPressed: loading ? null : load,
                child: const Text('Повторить загрузку'),
              ),
          ],
  );
}
