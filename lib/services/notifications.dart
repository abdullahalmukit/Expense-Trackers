import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/i18n.dart';

/// লোকাল নোটিফিকেশন — দৈনিক রিমাইন্ডার, বাজেট সতর্কতা, ধারের ফেরত-তারিখ, রিকারিং।
class Notify {
  Notify._();
  static final instance = Notify._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// নোটিফিকেশনে ট্যাপ করলে payload (যেমন 'add', 'debt')
  final ValueNotifier<String?> tapped = ValueNotifier(null);

  static const _dailyId = 1;
  static AndroidNotificationDetails get _channelReminder => AndroidNotificationDetails(
    'reminder',
    tr('রিমাইন্ডার', 'Reminders'),
    channelDescription: tr('দৈনিক খরচ লেখার রিমাইন্ডার', 'Daily reminder to log spending'),
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    color: Color(0xFF23308C),
  );
  static AndroidNotificationDetails get _channelBudget => AndroidNotificationDetails(
    'budget',
    tr('বাজেট সতর্কতা', 'Budget alerts'),
    channelDescription: tr('বাজেটের ৮০% ও ১০০% পার হলে', 'When 80% and 100% of a budget is used'),
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFFE5533D),
  );
  static AndroidNotificationDetails get _channelDebt => AndroidNotificationDetails(
    'debt',
    tr('ধারের রিমাইন্ডার', 'Debt reminders'),
    channelDescription: tr('ধার শোধ বা ফেরতের তারিখে', 'On debt repayment or return dates'),
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF7E57C2),
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tapped.value = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('notification init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async {
    await init();
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleDaily(TimeOfDay t) async {
    await init();
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: tr('আজকের খরচ লিখেছেন?', 'Logged today\'s spending?'),
      body: tr('এক ট্যাপে আজকের হিসাব লিখে রাখুন 📒', 'Record today\'s spending in one tap 📒'),
      scheduledDate: at,
      notificationDetails: NotificationDetails(android: _channelReminder),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'add',
    );
  }

  Future<void> cancelDaily() async {
    await init();
    if (_ready) await _plugin.cancel(id: _dailyId);
  }

  Future<void> budgetAlert(int id, String title, String body) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: 1000 + id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _channelBudget),
      payload: 'stats',
    );
  }

  static int _idFor(String key) => 100000 + (key.hashCode & 0x3fffffff) % 1000000;

  /// ধারের ফেরত-তারিখে সকাল ৯টায় রিমাইন্ডার
  Future<void> scheduleDebt(String txnId, DateTime due, String title, String body) async {
    await init();
    if (!_ready) return;
    final at = tz.TZDateTime(tz.local, due.year, due.month, due.day, 9);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: _idFor(txnId),
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(android: _channelDebt),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'debt',
    );
  }

  Future<void> cancelDebt(String txnId) async {
    await init();
    if (_ready) await _plugin.cancel(id: _idFor(txnId));
  }

  Future<void> showNow(int id, String title, String body, {String? payload}) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _channelReminder),
      payload: payload,
    );
  }
}
