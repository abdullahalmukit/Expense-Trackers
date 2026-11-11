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
import 'developer_card.dart';
import 'profile_screen.dart';
import 'lock_screen.dart';
import '../../core/i18n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final repo = ref.read(repoProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        t,
        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('সেটিংস', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // প্রোফাইল
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ProfileAvatar(
                  photo: s.raw[ProfileFields.photo],
                  name: s.raw[ProfileFields.name],
                ),
                title: Text(
                  s.raw[ProfileFields.name] ?? tr('প্রোফাইল যোগ করুন', 'Add your profile'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                subtitle: Text(
                  [s.raw[ProfileFields.phone], s.raw[ProfileFields.email]]
                      .whereType<String>()
                      .join(' · ')
                      .ifEmpty(tr('নাম, মোবাইল, ইমেইল, ছবি', 'Name, mobile, email, photo')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => go(const ProfileScreen()),
              ),
            ),
          ),
          header(tr('ভাষা', 'Language')),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('বাংলা / English'),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'bn', label: Text('বাংলা')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {s.english ? 'en' : 'bn'},
              onSelectionChanged: (v) => repo.setLanguage(v.first),
            ),
          ),
          header(tr('হিসাব', 'Accounts')),
          ListTile(
            leading: const Text('🏷️', style: TextStyle(fontSize: 22)),
            title: Text(tr('ক্যাটাগরি', 'Categories')),
            subtitle: Text(tr('নাম, ইমোজি, রং, ক্রম', 'Name, emoji, colour, order')),
            onTap: () => go(const CategoriesScreen()),
          ),
          ListTile(
            leading: const Text('👥', style: TextStyle(fontSize: 22)),
            title: Text(tr('ব্যক্তি', 'People')),
            onTap: () => go(const PersonsScreen()),
          ),
          ListTile(
            leading: const Text('👛', style: TextStyle(fontSize: 22)),
            title: Text(tr('ওয়ালেট ও ট্রান্সফার', 'Wallets & transfers')),
            subtitle: Text(
              tr(
                'ক্যাশ, bKash, Nagad, ব্যাংক · শুরুর ব্যালেন্স',
                'Cash, bKash, Nagad, bank · opening balance',
              ),
            ),
            onTap: () => go(const WalletsScreen()),
          ),
          ListTile(
            leading: const Text('📊', style: TextStyle(fontSize: 22)),
            title: Text(tr('মাসিক বাজেট', 'Monthly budget')),
            onTap: () => go(const BudgetsScreen()),
          ),
          ListTile(
            leading: const Text('🎯', style: TextStyle(fontSize: 22)),
            title: Text(tr('সঞ্চয়ের লক্ষ্য', 'Savings goals')),
            onTap: () => go(const GoalsScreen()),
          ),
          ListTile(
            leading: const Text('🔁', style: TextStyle(fontSize: 22)),
            title: Text(tr('রিকারিং এন্ট্রি', 'Recurring entries')),
            subtitle: Text(tr('মেস ভাড়া, ইন্টারনেট বিল', 'Rent, internet bill')),
            onTap: () => go(const RecurringScreen()),
          ),
          ListTile(
            leading: const Text('#️⃣', style: TextStyle(fontSize: 22)),
            title: Text(tr('ট্যাগ', 'Tags')),
            onTap: () => go(const TagsScreen()),
          ),

          header(tr('ডাটা', 'Data')),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(tr('এক্সপোর্ট', 'Export')),
            subtitle: const Text('JSON, Excel, CSV, PDF, Word'),
            onTap: () => go(const ExportScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(tr('ইমপোর্ট', 'Import')),
            subtitle: Text(tr('JSON, Excel বা CSV ফাইল থেকে', 'From a JSON, Excel or CSV file')),
            onTap: () => startImport(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.backup_outlined),
            title: Text(tr('অটো ব্যাকআপ', 'Auto backup')),
            subtitle: Text(
              switch (s.autoBackup) {
                    'off' => tr('বন্ধ', 'Off'),
                    'monthly' => tr('মাস শেষে', 'At month end'),
                    _ => tr('প্রতি সপ্তাহে', 'Every week'),
                  } +
                  (s.lastBackup != null
                      ? tr(
                          ' · শেষ: ${dateTimeLabel(s.lastBackup!)}',
                          ' · Last: ${dateTimeLabel(s.lastBackup!)}',
                        )
                      : ''),
            ),
            trailing: DropdownButton<String>(
              value: s.autoBackup,
              underline: SizedBox(),
              items: [
                DropdownMenuItem(value: 'weekly', child: Text(tr('সাপ্তাহিক', 'Weekly'))),
                DropdownMenuItem(value: 'monthly', child: Text(tr('মাসিক', 'Monthly'))),
                DropdownMenuItem(value: 'off', child: Text(tr('বন্ধ', 'Off'))),
              ],
              onChanged: (v) => repo.setSetting('auto_backup', v!),
            ),
            onTap: () => go(BackupsScreen()),
          ),

          header(tr('দেখানো', 'Display')),
          ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text(tr('থিম', 'Theme')),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(tr('অটো', 'Auto'))),
                ButtonSegment(value: 'light', label: Text(tr('লাইট', 'Light'))),
                ButtonSegment(value: 'dark', label: Text(tr('ডার্ক', 'Dark'))),
              ],
              selected: {s.raw['theme'] ?? 'system'},
              onSelectionChanged: (v) => repo.setSetting('theme', v.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: Text(tr('বাংলা সংখ্যা', 'Bengali digits')),
            subtitle: Text(s.bengaliDigits ? '৳১,২৩৪.৫০' : '৳1,234.50'),
            value: s.bengaliDigits,
            onChanged: (v) => repo.setSetting('digits', v ? 'bn' : 'en'),
          ),

          header(tr('নোটিফিকেশন', 'Notifications')),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(tr('দৈনিক রিমাইন্ডার', 'Daily reminder')),
            subtitle: Text(
              tr(
                'রাতে \'আজকের খরচ লিখেছেন?\' · ${_time(s.reminderTime)}',
                '\'Logged today\'s spending?\' · ${_time(s.reminderTime)}',
              ),
            ),
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
              title: Text(tr('রিমাইন্ডারের সময়', 'Reminder time')),
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
            title: Text(tr('বাজেট সতর্কতা', 'Budget alerts')),
            subtitle: Text(tr('৮০% আর ১০০% পার হলে', 'At 80% and 100%')),
            value: s.budgetAlerts,
            onChanged: (v) async {
              if (v) await Notify.instance.requestPermission();
              await repo.setSetting('budget_alerts', v ? '1' : '0');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: Text(tr('ধারের ফেরত-তারিখে রিমাইন্ডার', 'Debt due-date reminders')),
            value: s.debtReminders,
            onChanged: (v) async {
              if (v) await Notify.instance.requestPermission();
              await repo.setSetting('debt_reminders', v ? '1' : '0');
            },
          ),

          header(tr('নিরাপত্তা', 'Security')),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(tr('অ্যাপ লক (PIN)', 'App lock (PIN)')),
            value: s.lockEnabled,
            onChanged: (v) async {
              if (v) {
                final hash = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const SetPinScreen()),
                );
                if (hash != null) {
                  await repo.setSetting('lock_pin', hash);
                  if (context.mounted) toast(context, tr('অ্যাপ লক চালু হয়েছে', 'App lock is on'));
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
              title: Text(tr('ফিঙ্গারপ্রিন্ট দিয়েও খোলা', 'Also unlock with fingerprint')),
              value: s.lockBiometric,
              onChanged: (v) async {
                if (v && !await biometricAvailable()) {
                  if (context.mounted) {
                    toast(
                      context,
                      tr(
                        'এই ফোনে ফিঙ্গারপ্রিন্ট পাওয়া যায়নি',
                        'No fingerprint sensor found on this phone',
                      ),
                    );
                  }
                  return;
                }
                if (v && !await authenticateBiometric()) return;
                await repo.setSetting('lock_bio', v ? '1' : '0');
              },
            ),

          header(tr('সম্পর্কে', 'About')),
          ListTile(
            leading: const AppLogo(size: 36),
            title: Text(tr('টাকার খাতা', 'Takar Khata')),
            subtitle: Text(
              tr(
                'সংস্করণ ${dg('1.0.0')} · সম্পূর্ণ অফলাইন — কোনো সার্ভার, লগইন বা ইন্টারনেট লাগে না',
                'Version ${dg('1.0.0')} · Fully offline — no server, login or internet needed',
              ),
            ),
          ),
          header(tr('ডেভেলপার', 'Developer')),
          const DeveloperCard(),
        ],
      ),
    );
  }

  static String _time(TimeOfDay t) => timeLabel(DateTime(2000, 1, 1, t.hour, t.minute));
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
