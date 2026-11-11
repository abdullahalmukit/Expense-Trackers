import 'i18n.dart';
import 'money.dart';

const bnMonths = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

const bnMonthsShort = [
  'জানু',
  'ফেব্রু',
  'মার্চ',
  'এপ্রি',
  'মে',
  'জুন',
  'জুলা',
  'আগ',
  'সেপ্টে',
  'অক্টো',
  'নভে',
  'ডিসে',
];

const enMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const enWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// বর্তমান ভাষায় মাসের নাম (1–12)
String monthName(int m) => Lang.en ? enMonths[m - 1] : bnMonths[m - 1];
String monthNameShort(int m) => Lang.en ? enMonths[m - 1].substring(0, 3) : bnMonthsShort[m - 1];
String weekdayName(int w) => Lang.en ? enWeekdays[w - 1] : bnWeekdays[w - 1];

/// DateTime.weekday: 1 = সোমবার … 7 = রবিবার
const bnWeekdays = ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'];

const bnWeekdaysShort = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime nextMonth(DateTime d) => DateTime(d.year, d.month + 1);
DateTime prevMonth(DateTime d) => DateTime(d.year, d.month - 1);
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
DateTime parseMonthKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]));
}

/// "নভেম্বর ২০২৬"
String monthLabel(DateTime d) => '${monthName(d.month)} ${dg(d.year)}';
String monthShortLabel(DateTime d) => '${monthNameShort(d.month)} ${dg(d.year % 100)}';

/// "১০ নভেম্বর" (বছর আলাদা হলে বছরও)
String dayLabel(DateTime d, {bool withYear = false}) {
  final now = DateTime.now();
  final y = withYear || d.year != now.year ? ' ${dg(d.year)}' : '';
  return '${dg(d.day)} ${monthName(d.month)}$y';
}

/// "আজ", "গতকাল", অথবা "সোমবার, ১০ নভেম্বর"
String relativeDayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return '${tr('আজ', 'Today')} · ${dayLabel(d)}';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) {
    return '${tr('গতকাল', 'Yesterday')} · ${dayLabel(d)}';
  }
  return '${weekdayName(d.weekday)}, ${dayLabel(d)}';
}

String _period(int h) {
  if (h < 4) return 'রাত';
  if (h < 12) return 'সকাল';
  if (h < 15) return 'দুপুর';
  if (h < 18) return 'বিকাল';
  if (h < 20) return 'সন্ধ্যা';
  return 'রাত';
}

/// "রাত ৯:৩০" / "9:30 PM"
String timeLabel(DateTime d) {
  var h = d.hour % 12;
  if (h == 0) h = 12;
  final mm = dg(d.minute.toString().padLeft(2, '0'));
  if (Lang.en) return '${dg(h)}:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
  return '${_period(d.hour)} ${dg(h)}:$mm';
}

String dateTimeLabel(DateTime d) => '${dayLabel(d)}, ${timeLabel(d)}';

/// ফাইলের নামের জন্য: 2026-11-11
String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String isoDateTime(DateTime d) =>
    '${isoDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// একটি তারিখ পরিসর [start, end) — end বাদ।
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  int get days => end.difference(start).inDays;

  factory DateRange.month(DateTime m) => DateRange(monthStart(m), nextMonth(monthStart(m)));

  /// শেষ n মাস (এই মাস সহ)
  factory DateRange.lastMonths(DateTime m, int n) =>
      DateRange(DateTime(m.year, m.month - (n - 1)), nextMonth(monthStart(m)));

  factory DateRange.year(DateTime m) => DateRange(DateTime(m.year), DateTime(m.year + 1));

  /// সব মাসের তালিকা (প্রতিটির ১ তারিখ)
  List<DateTime> get months {
    final out = <DateTime>[];
    var m = monthStart(start);
    while (m.isBefore(end)) {
      out.add(m);
      m = nextMonth(m);
    }
    return out;
  }

  String get label {
    final last = end.subtract(const Duration(days: 1));
    if (start.day == 1 && sameMonth(start, last) && end.day == 1) {
      return monthLabel(start);
    }
    return '${dayLabel(start, withYear: true)} – ${dayLabel(last, withYear: true)}';
  }
}
