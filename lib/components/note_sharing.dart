import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../api/constants.dart';
import '../api/v2/request.dart';
import '../apiMapper/session.dart';
import '../apiMapper/v2/errors.dart';
import '../domain/companion.dart';
import '../store/store.dart';
import 'api_error_view.dart' show failureMessage;

class NoteSharingButton extends StatelessWidget {
  final String noteId;
  const NoteSharingButton({super.key, required this.noteId});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteSharingSheet(noteId: noteId),
    ),
    child: const Text('Доступ к заметке'),
  );
}

class _NoteSharingSheet extends StatefulWidget {
  final String noteId;
  const _NoteSharingSheet({required this.noteId});
  @override
  State<_NoteSharingSheet> createState() => _NoteSharingSheetState();
}

class _NoteSharingSheetState extends State<_NoteSharingSheet> {
  final userId = appStore?.state.auth.userId;
  CompanionJson? data;
  String error = '';
  bool busy = true;
  StreamSubscription? subscription;
  @override
  void initState() {
    super.initState();
    load();
    subscription = appStore?.onChange.listen((state) {
      if (state.auth.userId != userId && mounted) {
        setState(() {
          data = null;
          error = 'Вход изменился. Откройте заметку заново.';
          busy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<CompanionJson> request(String method, {CompanionJson? body}) async {
    if (userId == null || appStore?.state.auth.userId != userId) {
      throw StateError('Войдите в аккаунт.');
    }
    final r = await withSession(
      () => v2Send(
        method,
        v2Uri('/notes/sharing', method == 'GET' ? {'id': widget.noteId} : null),
        body: body,
      ),
    );
    if (appStore?.state.auth.userId != userId) {
      throw StateError('Вход изменился.');
    }
    if (r.statusCode != 200) {
      throwV2Error(
        r,
        'Не удалось изменить доступ к заметке. Сначала синхронизируйте запись.',
      );
    }
    final result = companionMap(jsonDecode(r.body));
    if (result['userId'] != userId) throw StateError('Вход изменился.');
    return result;
  }

  Future<void> load() async {
    try {
      final result = await request('GET');
      if (mounted) setState(() => data = {...?data, ...result});
    } catch (e) {
      if (mounted) {
        setState(
          () => error = failureMessage(
            e,
            'Не удалось получить настройки заметки',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle() async {
    if (busy || data == null) return;
    final publish = data!['published'] != true;
    if (publish) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Опубликовать заметку?'),
          content: const Text(
            'Любой получатель ссылки увидит эту заметку и выделенный фрагмент. Остальные ваши записи останутся приватными.',
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
      busy = true;
      error = '';
    });
    try {
      final result = await request(
        'POST',
        body: {
          'id': widget.noteId,
          'expectedUserId': userId,
          'expectedRevision': data!['revision'],
          'expectedNoteRevision': data!['noteRevision'],
          'published': publish,
        },
      );
      if (mounted) setState(() => data = {...?data, ...result});
    } catch (e) {
      if (mounted) {
        setState(() => error = failureMessage(e, 'Не удалось изменить доступ'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = data?['shareToken'];
    final link = token == null ? '' : '$apiBaseUrl/notes/shared/$token';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Доступ к заметке',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (busy) const LinearProgressIndicator(),
              if (data?['preview'] is Map) ...[
                const Text('Сохранённая версия заметки:'),
                Text('${companionMap(data!['preview'])['quote'] ?? ''}'),
                Text('${companionMap(data!['preview'])['text'] ?? ''}'),
              ],
              if (data != null)
                Text(
                  data!['published'] == true
                      ? 'Доступна по ссылке. Изменения заметки также видны получателям ссылки.'
                      : 'Приватная. Видна только вам.',
                ),
              TextButton(
                onPressed: busy || data == null ? null : toggle,
                child: Text(
                  data?['published'] == true
                      ? 'Отключить доступ по ссылке'
                      : 'Опубликовать по ссылке',
                ),
              ),
              if (link.isNotEmpty) ...[
                SelectableText(link),
                TextButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: link)),
                  child: const Text('Скопировать ссылку'),
                ),
                TextButton(
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(text: link)),
                  child: const Text('Поделиться'),
                ),
              ],
              if (error.isNotEmpty) Text(error),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() {
                          busy = true;
                          error = '';
                        });
                        load();
                      },
                child: const Text('Обновить настройки'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
