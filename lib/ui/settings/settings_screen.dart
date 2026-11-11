import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../providers.dart';
import '../../services/notifications.dart';
import '../manage/budgets_screen.dart';
import '../manage/categories_screen.dart';
import '../manage/goals_screen.dart';
import '../manage/persons_screen.dart';
import '../manage/recurring_screen.dart';
import '../manage/tags_screen.dart';
import '../manage/wallets_screen.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'data_screens.dart';
import 'lock_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final repo = ref.read(repoProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          header('হিসাব'),
          ListTile(leading: const Text('🏷️', style: TextStyle(fontSize: 22)), title: const Text('ক্যাটাগরি'), subtitle: const Text('নাম, ইমোজি, রং, ক্রম'), onTap: () => go(const CategoriesScreen())),
          ListTile(leading: const Text('👥', style: TextStyle(fontSize: 22)), title: const Text('ব্যক্তি'), onTap: () => go(const PersonsScreen())),
          ListTile(leading: const Text('👛', style: TextStyle(fontSize: 22)), title: const Text('ওয়ালেট ও ট্রান্সফার'), subtitle: const Text('ক্যাশ, bKash, Nagad, ব্যাংক · শুরুর ব্যালেন্স'), onTap: () => go(const WalletsScreen())),
          ListTile(leading: const Text('📊', style: TextStyle(fontSize: 22)), title: const Text('মাসিক বাজেট'), onTap: () => go(const BudgetsScreen())),
          ListTile(leading: const Text('🎯', style: TextStyle(fontSize: 22)), title: const Text('সঞ্চয়ের লক্ষ্য'), onTap: () => go(const GoalsScreen())),
          ListTile(leading: const Text('🔁', style: TextStyle(fontSize: 22)), title: const Text('রিকারিং এন্ট্রি'), subtitle: const Text('মেস ভাড়া, ইন্টারনেট বিল'), onTap: () => go(const RecurringScreen())),
          ListTile(leading: const Text('#️⃣', style: TextStyle(fontSize: 22)), title: const Text('ট্যাগ'), onTap: () => go(const TagsScreen())),

          header('ডাটা'),
          ListTile(leading: const Icon(Icons.upload_file), title: const Text('এক্সপোর্ট'), subtitle: const Text('JSON, Excel, CSV, PDF, Word'), onTap: () => go(const ExportScreen())),
          ListTile(leading: const Icon(Icons.download_for_offline_outlined), title: const Text('ইমপোর্ট'), subtitle: const Text('JSON, Excel বা CSV ফাইল থেকে'), onTap: () => startImport(context, ref)),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('অটো ব্যাকআপ'),
            subtitle: Text(
              '${switch (s.autoBackup) { 'off' => 'বন্ধ', 'monthly' => 'মাস শেষে', _ => 'প্রতি সপ্তাহে' }}'
              '${s.lastBackup != null ? ' · শেষ: ${dateTimeLabel(s.lastBackup!)}' : ''}',
            ),
            trailing: DropdownButton<String>(
              value: s.autoBackup,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('সাপ্তাহিক')),
                DropdownMenuItem(value: 'monthly', child: Text('মাসিক')),
                DropdownMenuItem(value: 'off', child: Text('বন্ধ')),
              ],
              onChanged: (v) => repo.setSetting('auto_backup', v!),
            ),
            onTap: () => go(const BackupsScreen()),
          ),

          header('দেখানো'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('থিম'),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'system', label: Text('অটো')),
                ButtonSegment(value: 'light', label: Text('লাইট')),
                ButtonSegment(value: 'dark', label: Text('ডার্ক')),
              ],
              selected: {s.raw['theme'] ?? 'system'},
              onSelectionChanged: (v) => repo.setSetting('theme', v.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: const Text('বাংলা সংখ্যা'),
            subtitle: Text(s.bengaliDigits ? '৳১,২৩৪.৫০' : '৳1,234.50'),
            value: s.bengaliDigits,
            onChanged: (v) => repo.setSetting('digits', v ? 'bn' : 'en'),
          ),

          header('নোটিফিকেশন'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('দৈনিক রিমাইন্ডার'),
            subtitle: Text('রাতে \'আজকের খরচ লিখেছেন?\' · ${_time(s.reminderTime)}'),
            value: s.reminderEnabled,
            onChanged: (v) async {
              if (v) {
                await Notify.instance.requestPermission();
                await Notify.instance.scheduleDaily(s.reminderTime);
              } else {
                await Notify.instance.cancelDaily();
              }
              await repo.setSetting('reminder', v ? '1' : '0');
            },
          ),
          if (s.reminderEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('রিমাইন্ডারের সময়'),
              trailing: Text(_time(s.reminderTime)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: s.reminderTime);
                if (t == null) return;
                await repo.setSetting('reminder_time', '${t.hour}:${t.minute}');
                await Notify.instance.scheduleDaily(t);
              },
            ),
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_outlined),
            title: const Text('বাজেট সতর্কতা'),
            subtitle: const Text('৮০% আর ১০০% পার হলে'),
            value: s.budgetAlerts,
            onChanged: (v) async {
              if (v) await Notify.instance.requestPermission();
              await repo.setSetting('budget_alerts', v ? '1' : '0');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('ধারের ফেরত-তারিখে রিমাইন্ডার'),
            value: s.debtReminders,
            onChanged: (v) async {
              if (v) await Notify.instance.requestPermission();
              await repo.setSetting('debt_reminders', v ? '1' : '0');
            },
          ),

          header('নিরাপত্তা'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('অ্যাপ লক (PIN)'),
            value: s.lockEnabled,
            onChanged: (v) async {
              if (v) {
                final hash = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SetPinScreen()));
                if (hash != null) {
                  await repo.setSetting('lock_pin', hash);
                  if (context.mounted) toast(context, 'অ্যাপ লক চালু হয়েছে');
                }
              } else {
                await repo.removeSetting('lock_pin');
                await repo.removeSetting('lock_bio');
              }
            },
          ),
          if (s.lockEnabled)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('ফিঙ্গারপ্রিন্ট দিয়েও খোলা'),
              value: s.lockBiometric,
              onChanged: (v) async {
                if (v && !await biometricAvailable()) {
                  if (context.mounted) toast(context, 'এই ফোনে ফিঙ্গারপ্রিন্ট পাওয়া যায়নি');
                  return;
                }
                if (v && !await authenticateBiometric()) return;
                await repo.setSetting('lock_bio', v ? '1' : '0');
              },
            ),

          header('সম্পর্কে'),
          ListTile(
            leading: const AppLogo(size: 36),
            title: const Text('টাকার খাতা'),
            subtitle: Text('সংস্করণ ${dg('1.0.0')} · সম্পূর্ণ অফলাইন — কোনো সার্ভার, লগইন বা ইন্টারনেট লাগে না'),
          ),
        ],
      ),
    );
  }

  static String _time(TimeOfDay t) => timeLabel(DateTime(2000, 1, 1, t.hour, t.minute));
}
