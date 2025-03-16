import 'dart:ui';
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';

import 'package:typikon/models/color.dart';

@immutable
class Common {
  final DateTime date;

  Common({
    required this.date,
  });

  factory Common.init() => Common(date: DateTime.now());

  Common copyWith({
    required DateTime date,
  }) {
    return Common(
      date: date,
    );
  }

  @override
  int get hashCode =>
      date.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Common &&
              date == other.date;

  @override
  String toString() {
    return 'Common{date: $date}';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch.toString(),
    };
  }

  static fromJson(Map<String, dynamic> json) {
    return Common(
      date: DateTime.fromMillisecondsSinceEpoch(int.parse(json["date"])),
    );
  }
}