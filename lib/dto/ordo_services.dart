/// Линейное чтение служб, полученных из пакета .ordo.
/// Порядок и повторы сохраняются; роли, positions и тетради не выводятся.
class OrdoSection {
  final String title;
  final List<String> texts;
  const OrdoSection(this.title, this.texts);
}

class OrdoService {
  final String title;
  final String? error;
  final List<OrdoSection> sections;
  const OrdoService(this.title, this.sections, {this.error});

  factory OrdoService.fromJson(Map<String, dynamic> json) {
    final sections = <OrdoSection>[];
    void readStep(dynamic step) {
      if (step is! Map) return;
      final texts = <String>[];
      void add(dynamic value) {
        if (value is String && value.trim().isNotEmpty) texts.add(value);
      }

      void flush(String title) {
        if (title.isNotEmpty || texts.isNotEmpty) {
          sections.add(OrdoSection(title, List.of(texts)));
        }
        texts.clear();
      }

      var title = step['label'] as String? ?? '';
      add(step['text']);
      if (step['body_absent'] != null && texts.isEmpty) {
        texts.add(ordoAbsentText(step['body_absent']));
      }
      for (final item in (step['items'] as List? ?? const [])) {
        if (item is! Map) continue;
        if (item['is_nested_step'] == true) {
          flush(title);
          title = '';
          readStep(item['step']);
          continue;
        }
        if (item['is_ode_header'] == true || item['is_canon_head'] == true) {
          flush(title);
          title = item['is_ode_header'] == true
              ? 'Песнь ${item['ode'] ?? ''}'
              : item['canon_label'] as String? ??
                    item['book_label'] as String? ??
                    'Канон';
          continue;
        }
        final text = item['text'];
        if (text is String && text.trim().isNotEmpty) {
          add(text);
        } else {
          add(ordoAbsentText(item['absent']));
          if (item['absent'] == 'external') {
            add(item['cite'] ?? item['address']);
          }
        }
      }
      final repeats = step['repeat_count'];
      if (repeats is int && repeats > 1) add('(Повторить $repeats раз)');
      flush(title);
    }

    for (final step in (json['steps'] as List? ?? const [])) {
      readStep(step);
    }
    return OrdoService(
      json['label'] as String? ?? json['key'] as String? ?? 'Служба',
      sections,
      error: json['error'] as String?,
    );
  }
}

String ordoAbsentText(dynamic reason) => switch (reason) {
  'rights' => 'Текст не предоставлен правообладателем.',
  'external' => 'Текст Писания не включён в пакет.',
  'unset' => 'Текст требует настройки службы.',
  'omitted' => 'Текст не включён в пакет.',
  _ => 'Текст этого места не собран.',
};

class OrdoServices {
  final List<OrdoService> services;
  const OrdoServices(this.services);
  factory OrdoServices.fromJson(Map<String, dynamic> json) {
    if (json['services'] is! List) {
      throw const FormatException('В ответе нет служб дня');
    }
    return OrdoServices(
      (json['services'] as List)
          .whereType<Map>()
          .map((s) => OrdoService.fromJson(Map<String, dynamic>.from(s)))
          .toList(growable: false),
    );
  }
}
