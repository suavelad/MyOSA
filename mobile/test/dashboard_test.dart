import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Needed for fonts
import 'package:myosa_baby_monitor/screens/dashboard_screen.dart';
import 'package:myosa_baby_monitor/services/api_service.dart';
import 'package:myosa_baby_monitor/services/mqtt_service.dart';

// Manual Mocks
class MockApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> getDashboardStats() async {
    return {"total_devices": 5, "readings_24h": 100, "alerts_24h": 2};
  }

  @override
  Future<List<dynamic>> getChartData(String deviceId,
      {String period = '24h', String? metric}) async {
    return [
      {
        "ts": "2023-10-27T10:00:00",
        "val": 1,
        "payload": {"temperature": 22.5, "humidity": 45, "sound": 30}
      },
      {
        "ts": "2023-10-27T10:05:00",
        "val": 1,
        "payload": {"temperature": 23.0, "humidity": 46, "sound": 32}
      },
    ];
  }
}

class MockMqttService extends MqttService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Stream<String> get alertStream => _controller.stream;

  @override
  Future<void> connect(String deviceId) async {}

  void emitAlert(String alert) {
    _controller.add(alert);
  }
}

void main() {
  setUpAll(() {
    // GoogleFonts needs http? or loading. In tests, we often Mock or allow HTTP.
    // For simple widget testing without networking, we can sometimes ignore font loading issues
    // or we might see a FlutterError. Let's see.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Enhanced Dashboard loads and displays multiple metrics',
      (WidgetTester tester) async {
    // Setup Mocks
    final mockApi = MockApiService();
    final mockMqtt = MockMqttService();

    // Pump Widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          Provider<MqttService>.value(value: mockMqtt),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Verify Loading State
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for Futures to complete
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('MyOSA Monitor'), findsOneWidget);

    // Verify Hero Stat (Humidity is default now that Temperature is hidden)
    expect(find.text('HUMIDITY'), findsWidgets);
    expect(find.text('46.0'), findsWidgets); // Latest value

    // Verify Environment Grid keys
    expect(find.text('HUMIDITY'), findsWidgets);
    expect(find.text('SOUND'), findsWidgets);

    // Verify Alerts Section
    expect(find.text('All systems normal'), findsOneWidget);
  });

  testWidgets('Fall Impact Graph aggregates correctly',
      (WidgetTester tester) async {
    final mockApi = MockApiService();
    final mockMqtt = MockMqttService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          Provider<MqttService>.value(value: mockMqtt),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Select Fall Impact Metric
    // Note: We might need to tap the metric selector if it's not default.
    // Based on previous changes, humidity is default.
    await tester.tap(find.text('FALL_IMPACT'));
    await tester.pumpAndSettle();

    // Verify Title changed in Hero
    expect(find.text('FALL IMPACTS (24h)'), findsOneWidget);

    // Verify Hero Sum (2 falls in mock data)
    expect(find.text('2'), findsWidgets);

    // Verify Unit Label
    expect(find.text('falls'), findsWidgets);

    // Verify X-Axis Date (10:00 from 2023-10-27T10:00:00)
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('Fall Impact Graph aggregates by day for 7d view',
      (WidgetTester tester) async {
    final mockApi = MockApiService();
    final mockMqtt = MockMqttService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          Provider<MqttService>.value(value: mockMqtt),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Select Fall Impact Metric
    await tester.tap(find.text('FALL_IMPACT'));
    await tester.pumpAndSettle();

    // Select 7d Period - Scroll if necessary
    final periodFinder = find.text('7D');
    await tester.ensureVisible(periodFinder);
    await tester.tap(periodFinder);
    await tester.pumpAndSettle();

    // Verify Title changed to include (7d)
    expect(find.text('FALL IMPACTS (7d)'), findsOneWidget);

    // Verify X-Axis Date format (10/27)
    expect(find.text('10/27'), findsOneWidget);
  });
}
