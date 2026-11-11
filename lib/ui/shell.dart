import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../providers.dart';
import '../services/notifications.dart';
import 'debt/debt_screen.dart';
import 'entry/entry_sheet.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'stats/stats_screen.dart';
import '../core/i18n.dart';

/// নিচে ট্যাব; মাঝের বড় + বাটন যেকোনো স্ক্রিন থেকে এন্ট্রি খোলে।
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  StreamSubscription<Uri?>? _widgetSub;

  static const _pages = [HomeScreen(), HistoryScreen(), StatsScreen(), DebtScreen()];

  @override
  void initState() {
    super.initState();
    // হোম স্ক্রিন উইজেট বা নোটিফিকেশন থেকে খোলা
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        _handleUri(uri);
        _widgetSub = HomeWidget.widgetClicked.listen(_handleUri);
      } catch (_) {}
      Notify.instance.tapped.addListener(_onNotification);
      _onNotification();
      ref.read(effectsProvider).refreshWidget();
    });
  }

  void _handleUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'add') showEntrySheet(context);
  }

  void _onNotification() {
    final p = Notify.instance.tapped.value;
    if (p == null || !mounted) return;
    Notify.instance.tapped.value = null;
    switch (p) {
      case 'add':
        showEntrySheet(context);
      case 'debt':
        ref.read(tabIndexProvider.notifier).set(3);
      case 'stats':
        ref.read(tabIndexProvider.notifier).set(2);
    }
  }

  @override
  void dispose() {
    _widgetSub?.cancel();
    Notify.instance.tapped.removeListener(_onNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);
    final scheme = Theme.of(context).colorScheme;
    Widget item(int i, IconData icon, IconData active, String label) {
      final sel = i == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ref.read(tabIndexProvider.notifier).set(i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? scheme.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  sel ? active : icon,
                  color: sel ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabIndexProvider.notifier).set(0);
      },
      child: Scaffold(
        // + বাটনের খাঁজের পেছনে পেজের রং দেখাতে
        extendBody: true,
        body: IndexedStack(index: index, children: _pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // আগের চেয়ে একটু ছোট + বাটন (৯৬ → ৬৬)
        floatingActionButton: SizedBox.square(
          dimension: 66,
          child: FloatingActionButton(
            heroTag: 'add',
            shape: const CircleBorder(),
            tooltip: tr('নতুন এন্ট্রি', 'New entry'),
            onPressed: () => showEntrySheet(context),
            child: const Icon(Icons.add, size: 34),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              item(0, Icons.home_outlined, Icons.home, tr('হোম', 'Home')),
              item(1, Icons.receipt_long_outlined, Icons.receipt_long, tr('হিস্টোরি', 'History')),
              const SizedBox(width: 80),
              item(2, Icons.pie_chart_outline, Icons.pie_chart, tr('পরিসংখ্যান', 'Statistics')),
              item(3, Icons.handshake_outlined, Icons.handshake, tr('ধার', 'Debt')),
            ],
          ),
        ),
      ),
    );
  }
}
