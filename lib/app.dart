import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n.dart';
import 'core/money.dart';
import 'core/theme.dart';
import 'providers.dart';
import 'services/backup.dart';
import 'services/notifications.dart';
import 'ui/settings/language_screen.dart';
import 'ui/settings/lock_screen.dart';
import 'ui/shell.dart';
import 'ui/widgets/logo.dart';

class TakaApp extends ConsumerStatefulWidget {
  const TakaApp({super.key});
  @override
  ConsumerState<TakaApp> createState() => _TakaAppState();
}

class _TakaAppState extends ConsumerState<TakaApp> with WidgetsBindingObserver {
  bool? _locked;
  DateTime? _pausedAt;
  bool _startupDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final s = ref.read(appSettingsProvider);
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      if (s.lockEnabled && away.inSeconds >= 30) setState(() => _locked = true);
      _pausedAt = null;
    }
  }

  /// অ্যাপ খোলার পরে: নোটিফিকেশন, রিকারিং এন্ট্রি, অটো ব্যাকআপ
  Future<void> _startup() async {
    if (_startupDone) return;
    _startupDone = true;
    final repo = ref.read(repoProvider);
    final s = ref.read(appSettingsProvider);
    await Notify.instance.init();
    if (s.reminderEnabled) await Notify.instance.scheduleDaily(s.reminderTime);
    try {
      final due = await repo.processRecurring();
      for (final r in due) {
        await Notify.instance.showNow(
          5000 + r.id,
          '🔁 ${r.title} — ${money(r.amount)}',
          tr('আজ এন্ট্রি দেওয়ার দিন। ট্যাপ করে যোগ করুন।', 'Entry due today. Tap to add it.'),
          payload: 'add',
        );
        await repo.advanceRecurring(r);
      }
    } catch (e) {
      debugPrint('recurring failed: $e');
    }
    try {
      if (Backup.isDue(s.autoBackup, s.lastBackup)) {
        await Backup.writeToBackupFolder(ref.read(dbProvider));
        await repo.setSetting('last_backup', DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('auto backup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(dataReadyProvider);
    final s = ref.watch(appSettingsProvider);
    Lang.en = s.english;
    NumFmt.bengali = s.bengaliDigits;
    if (ready && s.languageChosen) {
      _locked ??= s.lockEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
    }
    final Widget home;
    if (!ready) {
      home = const Scaffold(body: Center(child: AppLogo(size: 96)));
    } else if (!s.languageChosen) {
      home = const LanguageScreen();
    } else if (_locked == true && s.lockEnabled) {
      home = LockScreen(
        pinHash: s.raw['lock_pin']!,
        biometric: s.lockBiometric,
        onUnlock: () => setState(() => _locked = false),
      );
    } else {
      home = const Shell();
    }
    return MaterialApp(
      // সংখ্যার ভাষা বদলালে পুরো UI নতুন করে আঁকা
      key: ValueKey('${Lang.code}-${s.bengaliDigits}'),
      title: 'টাকার খাতা',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      locale: Lang.en ? const Locale('en') : const Locale('bn', 'BD'),
      supportedLocales: const [Locale('bn', 'BD'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
  }
}
