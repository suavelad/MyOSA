import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Map<String, dynamic>? _stats; // Removed unused
  List<dynamic> _chartData = [];
  final List<String> _alerts = [];
  final String _selectedDeviceId = 'device123'; // Default/First device
  bool _isLoading = true;

  // Multi-metric support
  Set<String> _availableMetrics = {'humidity'}; // Default to another metric
  String _selectedMetric = 'humidity';
  String _selectedPeriod = '24h';

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupMqtt();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      // final stats = await api.getDashboardStats(); // Unused

      String? metricParam;
      if (_selectedMetric == 'fall_impact') metricParam = 'fall_impact';

      final chartData = await api.getChartData(_selectedDeviceId,
          period: _selectedPeriod, metric: metricParam);

      // Analyze data to find available metrics
      Set<String> metrics = {};

      for (var item in chartData) {
        if (item['payload'] is Map) {
          item['payload'].forEach((k, v) {
            String key = k.toString().toLowerCase();
            if (v is num &&
                !key.contains('threshold') &&
                !key.contains('limit') &&
                key != 'val' &&
                key != 'value' &&
                key != 'severity_score' &&
                key != 'humidity') {
              metrics.add(k);
            }
          });
        }
      }

      // Always add fall_impact and temp as standard options
      metrics.addAll({'temp', 'fall_impact'});

      if (metrics.isEmpty) metrics = {'fall_impact'};

      setState(() {
        // _stats = stats;
        _chartData = chartData;
        _availableMetrics = metrics;

        // If selected metric is no longer available (and not fall_impact), reset
        if (!_availableMetrics.contains(_selectedMetric)) {
          if (_availableMetrics.isNotEmpty) {
            _selectedMetric = _availableMetrics.first;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _setupMqtt() {
    final mqtt = Provider.of<MqttService>(context, listen: false);
    mqtt.connect(_selectedDeviceId);

    // Listen for Alerts
    mqtt.alertStream.listen((alertPayload) {
      if (mounted) {
        setState(() {
          _alerts.insert(0, alertPayload);
          if (_alerts.length > 20) _alerts.removeLast();
        });
      }
    });

    // Listen for Telemetry (Real-time updates)
    mqtt.telemetryStream.listen((payloadStr) {
      if (!mounted) return;
      try {
        final data = json.decode(payloadStr);
        if (data is Map) {
          setState(() {
            // 1. Add to Chart Data
            // Create a new point with current time (mocked relative or actual)
            // For scrolling chart, we often just add point.
            // Since _chartData is list of {ts, payload}, we match that.
            _chartData
                .add({"ts": DateTime.now().toIso8601String(), "payload": data});
            if (_chartData.length > 50) {
              _chartData.removeAt(0); // Keep window size
            }

            // 2. Update Available Metrics if new keys appear
            data.forEach((k, v) {
              String key = k.toString().toLowerCase();
              if (v is num &&
                  !key.contains('threshold') &&
                  !key.contains('limit') &&
                  key != 'val' &&
                  key != 'value' &&
                  key != 'severity_score' &&
                  key != 'humidity') {
                // Filter out humidity
                // Filter out humidity
                _availableMetrics.add(k);
              }
            });
          });
        }
      } catch (e) {
        print("Error parsing telemetry: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deeper dark
      appBar: AppBar(
        title: Text('MyOSA Baby Monitor',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showConfigDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildConnectionStatus(),
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroStats(),
                    const SizedBox(height: 24),
                    _buildMetricSelector(),
                    const SizedBox(height: 16),
                    _buildMainChart(),
                    const SizedBox(height: 16),
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    Text(
                      'Environment',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    _buildEnvironmentGrid(),
                    const SizedBox(height: 24),
                    Text(
                      'Live Alerts',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    _buildAlertsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConnectionStatus() {
    // Mock status for visual
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text("Online",
              style: TextStyle(
                  color: Colors.green[300],
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    // Get latest value of selected metric
    double currentValue = 0;

    if (_selectedMetric == 'fall_impact') {
      // Sum of all falls in the period
      for (var item in _chartData) {
        if (item['val'] == 1) currentValue += 1;
      }
    } else if (_chartData.isNotEmpty) {
      var last = _chartData.last;
      if (last['payload'] is Map &&
          last['payload'].containsKey(_selectedMetric)) {
        currentValue = (last['payload'][_selectedMetric] as num).toDouble();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              blurRadius: 20,
              color: Colors.blueAccent.withOpacity(0.4),
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedMetric == 'fall_impact'
                ? "FALL IMPACTS ($_selectedPeriod)"
                : _selectedMetric.toUpperCase(),
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                letterSpacing: 1.2,
                fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _selectedMetric == 'fall_impact'
                    ? currentValue.toInt().toString()
                    : currentValue.toStringAsFixed(1),
                style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_getUnit(_selectedMetric),
                    style: TextStyle(
                        fontSize: 18, color: Colors.white.withOpacity(0.9))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini Sparkline or label
          Text("Last updated 1 min ago",
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }

  String _getUnit(String metric) {
    switch (metric.toLowerCase()) {
      case 'temperature':
        return '°C';
      case 'humidity':
        return '%';
      case 'battery':
        return '%';
      case 'sound':
        return 'dB';
      case 'fall_impact':
        return 'falls';
      default:
        return '';
    }
  }

  Widget _buildMetricSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableMetrics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final metric = _availableMetrics.elementAt(index);
          final isSelected = metric == _selectedMetric;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedMetric = metric);
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  metric.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['24h', '7d', '30d'].map((period) {
        final isSelected = _selectedPeriod == period;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ChoiceChip(
            label: Text(period.toUpperCase(),
                style:
                    TextStyle(color: isSelected ? Colors.black : Colors.white)),
            selected: isSelected,
            selectedColor: Colors.white,
            backgroundColor: const Color(0xFF2C2C2C),
            onSelected: (bool selected) {
              if (selected) {
                setState(() => _selectedPeriod = period);
                _loadData();
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainChart() {
    if (_chartData.isEmpty) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: Text("No data", style: TextStyle(color: Colors.grey))));
    }

    List<FlSpot> spots = [];
    List<String> xLabels = [];

    if (_selectedMetric == 'fall_impact') {
      // Aggregation Logic
      Map<String, double> aggregatedCounts = {};

      bool isDaily = _selectedPeriod == '7d' || _selectedPeriod == '30d';
      String dateFormat = isDaily ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH';

      for (var item in _chartData) {
        try {
          final date = DateTime.parse(item['ts']);
          final key = DateFormat(dateFormat).format(date);
          aggregatedCounts[key] =
              (aggregatedCounts[key] ?? 0) + (item['val'] ?? 1);
        } catch (e) {
          // ignore bad dates
        }
      }

      final sortedKeys = aggregatedCounts.keys.toList()..sort();
      for (int i = 0; i < sortedKeys.length; i++) {
        spots.add(FlSpot(i.toDouble(), aggregatedCounts[sortedKeys[i]]!));
        xLabels.add(sortedKeys[i]);
      }
    } else {
      for (int i = 0; i < _chartData.length; i++) {
        var item = _chartData[i];
        if (item['payload'] is Map &&
            item['payload'].containsKey(_selectedMetric)) {
          spots.add(FlSpot(i.toDouble(),
              (item['payload'][_selectedMetric] as num).toDouble()));
        }
      }
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 24, bottom: 12, right: 24, left: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
                axisNameWidget: Text(
                  _getUnit(_selectedMetric),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toInt().toString(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10));
                    })),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    interval: _selectedMetric == 'fall_impact'
                        ? 1
                        : (_chartData.length > 5
                            ? (_chartData.length / 5).floorToDouble()
                            : 1),
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();

                      if (_selectedMetric == 'fall_impact') {
                        if (index >= 0 && index < xLabels.length) {
                          try {
                            bool isDaily = _selectedPeriod == '7d' ||
                                _selectedPeriod == '30d';
                            // Parse using the same format as key
                            String dateFormat =
                                isDaily ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH';
                            final date =
                                DateFormat(dateFormat).parse(xLabels[index]);

                            String label = isDaily
                                ? DateFormat('MM/dd').format(date)
                                : DateFormat('HH:mm').format(date);

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(label,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 10)),
                            );
                          } catch (e) {
                            return const Text("");
                          }
                        }
                        return const Text("");
                      }

                      // Original Logic for other metrics
                      if (index >= 0 && index < _chartData.length) {
                        try {
                          final date = DateTime.parse(_chartData[index]['ts']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('HH:mm').format(date),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          );
                        } catch (e) {
                          return const Text("");
                        }
                      }
                      return const Text("");
                    })),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: _selectedMetric !=
                  'fall_impact', // Straight lines for frequency maybe? or kept curved.
              color: Colors.cyanAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: _selectedMetric ==
                      'fall_impact'), // Show dots for daily points
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.cyanAccent.withOpacity(0.3),
                    Colors.cyanAccent.withOpacity(0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentGrid() {
    // Show mini cards for other metrics
    // Mock data for now if single metric, or use latest from chart
    Map<String, double> latestValues = {};
    if (_chartData.isNotEmpty) {
      var last = _chartData.last['payload'];
      if (last is Map) {
        last.forEach((k, v) {
          if (v is num) latestValues[k] = v.toDouble();
        });
      }
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true, // Vital for nested ScrollView
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: latestValues.entries.map((e) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIconForMetric(e.key), color: Colors.grey, size: 20),
              const Spacer(),
              Text(e.value.toStringAsFixed(1) + _getUnit(e.key),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(e.key.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[500], letterSpacing: 1)),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForMetric(String key) {
    switch (key.toLowerCase()) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'battery':
        return Icons.battery_charging_full;
      case 'sound':
        return Icons.graphic_eq;
      default:
        return Icons.sensors;
    }
  }

  Widget _buildAlertsList() {
    if (_alerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16)),
        child: const Center(
            child: Text("All systems normal",
                style: TextStyle(color: Colors.greenAccent))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        // Parse JSON if possible
        String rawMsg = _alerts[index];
        String displayMsg = rawMsg;
        String time = DateFormat('HH:mm').format(DateTime.now());

        try {
          final data = json.decode(rawMsg);
          if (data is Map && data.containsKey('alert')) {
            String type =
                data['alert'].toString().replaceAll('_', ' ').toUpperCase();
            String value = '';
            if (data.containsKey('temperature')) {
              value = "${(data['temperature'] as num).toStringAsFixed(1)}°C";
            }
            if (data.containsKey('threshold')) {
              value += " (Limit: ${data['threshold']})";
            }
            displayMsg = "$type $value";
          }
        } catch (e) {
          // Keep raw message
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _alerts.removeAt(index);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(displayMsg,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500))),
                Text(time,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfigDialog() {
    final TextEditingController controller =
        TextEditingController(text: '35'); // Default
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text("Set Temperature Threshold",
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              suffixText: "°C",
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  try {
                    Map<String, dynamic> config = {"temp_threshold": val};
                    Provider.of<MqttService>(context, listen: false).publish(
                        'baby/$_selectedDeviceId/config', json.encode(config));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Threshold updated to $val°C")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to update: $e")));
                  }
                }
              },
              child:
                  const Text("Update", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }
}
