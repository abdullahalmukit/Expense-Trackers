import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/i18n.dart';
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
      await HomeWidget.saveWidgetData<String>('label_today', tr('আজকের খরচ', "Today's spending"));
      await HomeWidget.saveWidgetData<String>('label_month', tr('এ মাসে খরচ', 'This month'));
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }
}
