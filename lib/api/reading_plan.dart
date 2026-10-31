import 'v2/request.dart';
import 'package:http/http.dart' as http;

Future<http.Response> fetchReadingPlan() =>
    v2Send('GET', v2Uri('/reading-plan'));
Future<http.Response> changeReadingPlan(Map<String, dynamic> body) =>
    v2Send('PATCH', v2Uri('/reading-plan'), body: body);
Future<http.Response> fetchPlanNotice(String delivery) =>
    v2Send('GET', v2Uri('/reading-plan/notice', {'delivery': delivery}));
