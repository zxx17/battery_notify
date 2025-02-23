import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:battery_plus/battery_plus.dart';

class BatteryStatsPage extends StatefulWidget {
  const BatteryStatsPage({super.key});

  @override
  State<BatteryStatsPage> createState() => _BatteryStatsPageState();
}

class _BatteryStatsPageState extends State<BatteryStatsPage> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  List<FlSpot> _batteryLevels = [];
  int _chargeCount = 0;
  bool _isCharging = false;

  @override
  void initState() {
    super.initState();
    _initBatteryStats();
    _startBatteryMonitoring();
  }

  Future<void> _initBatteryStats() async {
    final batteryLevel = await _battery.batteryLevel;
    final batteryState = await _battery.batteryState;
    
    setState(() {
      _batteryLevel = batteryLevel;
      _isCharging = batteryState == BatteryState.charging;
      // 初始化电量数据点
      _batteryLevels = [FlSpot(DateTime.now().hour.toDouble(), batteryLevel.toDouble())];
    });
  }

  void _startBatteryMonitoring() {
    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      final batteryLevel = await _battery.batteryLevel;
      
      setState(() {
        _batteryLevel = batteryLevel;
        _isCharging = state == BatteryState.charging;
        if (state == BatteryState.charging && !_isCharging) {
          _chargeCount++;
        }
        
        // 添加新的电量数据点
        _batteryLevels.add(FlSpot(
          DateTime.now().hour.toDouble(), 
          batteryLevel.toDouble()
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('电池统计(完善中)',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          )
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '今日充电次数',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _isCharging 
                            ? Icons.battery_charging_full 
                            : Icons.battery_full,
                          color: Colors.green
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_chargeCount 次',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '24小时电量变化',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 6 == 0) {
                            return Text('${value.toInt()}:00');
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _batteryLevels,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 