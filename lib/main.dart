import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'battery_stats_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '充电提醒',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BatteryMonitorPage(),
    );
  }
}

class BatteryMonitorPage extends StatefulWidget {
  const BatteryMonitorPage({super.key});

  @override
  State<BatteryMonitorPage> createState() => _BatteryMonitorPageState();
}

class _BatteryMonitorPageState extends State<BatteryMonitorPage> {
  final Battery _battery = Battery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  BatteryState? _batteryState;
  int _batteryLevel = 0;
  bool _isMonitoring = false;
  bool _hasAlerted = false;
  int _alertThreshold = 88; // 默认88%时提醒
  int _repeatTimes = 3; // 默认重复3次
  int _playedTimes = 0; // 记录已播放次数
  DateTime? _lastPlayTime; // 记录上次播放时间
  String _selectedSound = 'default.mp3'; // 默认铃声
  final Map<String, String> _availableSounds = {
    'default.mp3': '默认铃声',
    'xiaomi.mp3': '小米经典',
  };

  // 添加 MethodChannel
  static const platform = MethodChannel('com.zxx17.battery_notify/battery');

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initBatteryState();
    _initNotifications();
    _startBatteryMonitor();
    _requestBatteryOptimizations();
  }

  @override
  void dispose() {
    _audioPlayer.stop();  // 确保音频停止播放
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initBatteryState() async {
    final batteryState = await _battery.batteryState;
    final batteryLevel = await _battery.batteryLevel;
    setState(() {
      _batteryState = batteryState;
      _batteryLevel = batteryLevel;
    });
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showMonitoringNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'battery_monitor_channel',
      '电池监控通知',
      channelDescription: '显示电池监控状态',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: false,
      playSound: false,
      enableVibration: false,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      1,
      '充电提醒',
      '正在监控手机充电状态 - 当前电量：$_batteryLevel%',
      notificationDetails,
    );
  }

  void _cancelMonitoringNotification() {
    _notificationsPlugin.cancel(1);
  }

  Future<void> _startBatteryMonitor() async {
    // 监听电池状态
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      setState(() {
        _batteryState = state;
      });
      _checkBatteryStatus();
    });

    // 定期检查电池电量
    Future.doWhile(() async {
      if (!_isMonitoring) return false;

      final batteryLevel = await _battery.batteryLevel;
      setState(() {
        _batteryLevel = batteryLevel;
      });

      await _checkBatteryStatus();
      await Future.delayed(const Duration(seconds: 5));
      return _isMonitoring;
    });
  }

  Future<void> _checkBatteryStatus() async {
    if (!_isMonitoring) return;

    // 更新通知栏显示的电量
    if (_isMonitoring) {
      _showMonitoringNotification();
    }

    // 如果不在充电状态，立即停止播放
    if (_batteryState != BatteryState.charging) {
      _hasAlerted = false;
      _playedTimes = 0;
      _lastPlayTime = null;
      await _audioPlayer.stop();  // 立即停止播放
      return;
    }

    if (_batteryState == BatteryState.charging &&
        _batteryLevel >= _alertThreshold &&
        !_hasAlerted) {
      _hasAlerted = true;
      _playedTimes = 0;
      await _playAlarm();
    } else if (_batteryLevel < (_alertThreshold - 5)) {
      _hasAlerted = false;
      _playedTimes = 0;
      _lastPlayTime = null;
    }
  }

  Future<void> _playAlarm() async {
    // 再次检查是否在充电状态，如果不在充电则不播放
    if (!_isMonitoring || _batteryState != BatteryState.charging || _playedTimes >= _repeatTimes) {
      return;
    }

    final now = DateTime.now();
    if (_lastPlayTime != null &&
        now.difference(_lastPlayTime!).inSeconds < 10) return;

    await _audioPlayer.play(AssetSource('static/$_selectedSound'));
    _lastPlayTime = now;
    _playedTimes++;

    if (_playedTimes < _repeatTimes && _batteryState == BatteryState.charging) {
      Future.delayed(const Duration(seconds: 10), _playAlarm);
    }
  }

  // 添加请求电池优化白名单的方法
  Future<void> _requestBatteryOptimizations() async {
    try {
      await platform.invokeMethod('requestBatteryOptimizations');
    } catch (e) {
      print('Failed to request battery optimizations: $e');
    }
  }

  // 修改开始监控方法
  void _toggleMonitoring() async {
    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _startBatteryMonitor();
        _showMonitoringNotification();
        _requestBatteryOptimizations();
      } else {
        _audioPlayer.stop();
        _cancelMonitoringNotification();
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _alertThreshold = 88;
      _repeatTimes = 3;
      _selectedSound = 'default.mp3';
    });
  }

  Future<void> _previewSound() async {
    await _audioPlayer.stop(); // 先停止当前播放
    await _audioPlayer.play(AssetSource('static/$_selectedSound'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 修改为白色背景
      appBar: AppBar(
        title: const Text('充电提醒', style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        )),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BatteryStatsPage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white, // 修改抽屉背景为白色
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/static/img/setting.png'),
                  fit: BoxFit.contain,  // 图片将覆盖整个header区域
                ),
              ),
              child: Text(
                '设置',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
            ),
            ListTile(
              title: const Text('提示音选择'),
              subtitle: Column(
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSound,
                    items: _availableSounds.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedSound = value;
                        });
                      }
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: _previewSound,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('试听'),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('提醒电量阈值'),
              subtitle: Slider(
                value: _alertThreshold.toDouble(),
                min: 20,
                max: 100,
                divisions: 80,
                label: '$_alertThreshold%',
                onChanged: (value) {
                  setState(() {
                    _alertThreshold = value.round();
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('提示音重复次数'),
              subtitle: Slider(
                value: _repeatTimes.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_repeatTimes次',
                onChanged: (value) {
                  setState(() {
                    _repeatTimes = value.round();
                  });
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: Text('当前设置：$_alertThreshold% / $_repeatTimes次'),
              subtitle: Text('选择铃声：${_availableSounds[_selectedSound]}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.restore),
                label: const Text('恢复默认设置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // 修改 Container 背景为白色
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: 1.5708, // 90度，使电池图标横向显示
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      child: Icon(
                        _batteryState == BatteryState.charging 
                            ? Icons.battery_charging_full_outlined 
                            : Icons.battery_full_outlined,
                        size: 100,
                        color: _batteryLevel > 70 
                            ? Color.lerp(Colors.blue, Colors.green, (_batteryLevel - 70) / 30)
                            : _batteryLevel > 20 
                                ? Color.lerp(Colors.yellow, Colors.blue, (_batteryLevel - 20) / 50)
                                : Color.lerp(Colors.red, Colors.pink, _batteryLevel / 20),
                      ),
                    ),
                  ),
                  Text(
                    '$_batteryLevel%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('充电状态:'),
                      Row(
                        children: [
                          Icon(
                            _batteryState == BatteryState.charging 
                                ? Icons.power
                                : Icons.power_off,
                            color: _batteryState == BatteryState.charging 
                                ? Colors.green 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _batteryState == BatteryState.charging ? "充电中" : "未充电",
                            style: TextStyle(
                              color: _batteryState == BatteryState.charging 
                                  ? Colors.green 
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('监控状态:'),
                      Row(
                        children: [
                          Icon(
                            _isMonitoring ? Icons.visibility : Icons.visibility_off,
                            color: _isMonitoring ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isMonitoring ? "开启" : "关闭",
                            style: TextStyle(
                              color: _isMonitoring ? Colors.blue : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleMonitoring,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(_isMonitoring ? '停止监控' : '开始监控'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
