class PlanReminderSettings {
  final bool enabled;
  final String time;
  final List<int> weekdays;
  final String timeZone;
  const PlanReminderSettings({
    required this.enabled,
    required this.time,
    required this.weekdays,
    required this.timeZone,
  });
  factory PlanReminderSettings.fromJson(Map<String, dynamic> j) =>
      PlanReminderSettings(
        enabled: j['enabled'] == true,
        time: j['time'] as String? ?? '08:00',
        weekdays: (j['weekdays'] as List? ?? [1, 2, 3, 4, 5, 6, 7])
            .whereType<int>()
            .toList(),
        timeZone: j['timeZone'] as String? ?? 'Europe/Moscow',
      );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'time': time,
    'weekdays': weekdays,
    'timeZone': timeZone,
  };
}

class PlanReading {
  final String title;
  final String? content;
  final List<String> footnotes;
  final bool markdown, csSource;
  PlanReading.fromJson(Map<String, dynamic> j)
    : title = j['title'] as String? ?? 'Очередное чтение',
      content = j['content'] as String?,
      footnotes = (j['footnotes'] as List? ?? []).whereType<String>().toList(),
      markdown = j['markdown'] == true,
      csSource = j['csSource'] == true;
}

class PersonalReadingPlan {
  final String userId, id, title, status;
  final int revision;
  final PlanReminderSettings? reminder;
  final PlanReading? current;
  PersonalReadingPlan.fromJson(Map<String, dynamic> j)
    : userId = j['userId'] as String,
      id = j['id'] as String,
      title = j['title'] as String,
      status = j['status'] as String,
      revision = j['revision'] as int,
      reminder = j['reminder'] is Map
          ? PlanReminderSettings.fromJson(
              Map<String, dynamic>.from(j['reminder']),
            )
          : null,
      current = j['current'] is Map
          ? PlanReading.fromJson(Map<String, dynamic>.from(j['current']))
          : null;
}

class PlanNotice {
  final String userId, planId, deliveryId, body;
  PlanNotice.fromJson(Map<String, dynamic> j)
    : userId = j['userId'] as String,
      planId = j['planId'] as String,
      deliveryId = j['deliveryId'] as String,
      body = j['body'] as String;
  String get payload => 'reading-plan:$userId:$planId';
}
