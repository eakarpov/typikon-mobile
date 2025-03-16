import 'dart:convert';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';

import '../api/contact.dart';

Future<Uint8List> fetchCaptcha() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  var token = "";
  if (true) { // only Android
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    token = androidInfo.fingerprint;
  }
  final response = await getCaptcha(token);

  if (response.statusCode == 200) {
    return response.bodyBytes;
  } else {
    throw Exception('Не получена книга');
  }
}

Future<bool> sendForm(String email, String theme, String message, String captcha) async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  var fingerprint = "";
  if (true) { // only Android
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    fingerprint = androidInfo.fingerprint;
  }
  final response = await sendFeedback(email, theme, message, captcha, fingerprint);

  if (response.statusCode == 200) {
    return true;
  } else {
    return false;
    // throw Exception('Не получена книга ${response.body} ${response.statusCode}');
  }
}