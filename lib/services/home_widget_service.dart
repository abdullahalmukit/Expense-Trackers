import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/money.dart';

/// হোম স্ক্রিন উইজেটে আজকের খরচ দেখানো
class HomeWidgetService {
  static const androidProvider = 'com.mukit.takar_khata.TakaWidgetProvider';

  static Future<void> update({
    required int todayExpense,
    required int monthExpense,
    required int balance,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>('today_expense', money(todayExpense));
      await HomeWidget.saveWidgetData<String>('month_expense', money(monthExpense));
      await HomeWidget.saveWidgetData<String>('balance', money(balance));
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }
}
