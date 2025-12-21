import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
  final String baseUrl;
  // TODO: Update IP for real device
  ApiService({this.baseUrl = 'http://localhost:8001'});

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/stats'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load stats');
    }
  }

  Future<List<dynamic>> getDevices() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/devices'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['devices'];
    } else {
      throw Exception('Failed to load devices');
    }
  }

  Future<List<dynamic>> getChartData(String deviceId,
      {String period = '24h', String? metric}) async {
    String query = 'period=$period';
    if (metric != null) {
      query += '&metric=$metric';
    }
    final url = Uri.parse('$baseUrl/dashboard/chart/$deviceId?$query');
    print('ApiService requesting: $url');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to load chart data: ${response.statusCode} - ${response.body}');
    }
  }
}
