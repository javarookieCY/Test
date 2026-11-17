import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._createNotificationService();

  static final NotificationService instance = NotificationService._createNotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'daily_summary';
  static const String _channelName = '每日摘要';
  static const String _channelDescription = '今日剩餘的熱量和蛋白質';

  static const int _summaryNotificationId = 0;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings();

    const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(defaultActionName: '打開');
    const WindowsInitializationSettings windowsSettings = WindowsInitializationSettings(
      appName: '健身飲食',
      appUserModelId: 'Com.Example.FlutterApplication1',
      guid: '6f1d2c4a-8b3e-4f7a-9c21-5d0e8a7b3f64',
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> _requestPermission() async {

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool? granted = await android.requestNotificationsPermission();
      if (granted == null) {
        return false;
      }
      return granted;
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final bool? granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      if (granted == null) {
        return false;
      }
      return granted;
    }

    return true;
  }

  Future<bool> showNow(String title, String body) async {
    await _ensureInitialized();

    final bool allowed = await _requestPermission();
    if (!allowed) {
      return false;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _summaryNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
    return true;
  }
}
