import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/network_diagnostics.dart';

class NetworkDiagnosticsPage extends StatefulWidget {
  const NetworkDiagnosticsPage({super.key});

  @override
  State<NetworkDiagnosticsPage> createState() => _NetworkDiagnosticsPageState();
}

class _NetworkDiagnosticsPageState extends State<NetworkDiagnosticsPage> {
  final _lines = <String>[];
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _lines.clear();
      _running = true;
    });
    try {
      await runNetworkDiagnostics((line) {
        if (mounted) setState(() => _lines.add(line));
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проверка сети и кэша')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Диагностическая сборка. Проверка обращается к серверу и создаёт временную запись кэша. '
          'Помянник, вход, прогресс и сохранённые чтения не удаляются. '
          'Отчёт автоматически не отправляется. Проверка может занять несколько минут.',
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Открывать разделы без HTTP-кэша'),
          subtitle: const Text(
            'Для сравнения: включите и снова откройте проблемный раздел. '
            'Сохранённые данные не удаляются. После перезапуска приложения переключатель выключится.',
          ),
          value: bypassHttpCacheForDiagnostics,
          onChanged: _running
              ? null
              : (value) =>
                    setState(() => bypassHttpCacheForDiagnostics = value),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Проверяем…' : 'Начать проверку'),
            ),
            OutlinedButton(
              onPressed: _lines.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: _lines.join('\n')),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Отчёт скопирован')),
                        );
                      }
                    },
              child: const Text('Скопировать отчёт'),
            ),
          ],
        ),
        if (_running)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 12),
        SelectableText(
          _lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    ),
  );
}
