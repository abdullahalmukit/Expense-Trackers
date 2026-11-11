import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../widgets/logo.dart';

/// প্রথমবার খুললে ভাষা বাছাই — দুই ভাষাতেই লেখা, যাতে যে কেউ বুঝতে পারে
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget option(String code, String title, String sub, String flag) => Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ref.read(repoProvider).setLanguage(code),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(sub),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const Center(child: AppLogo(size: 96)),
            const SizedBox(height: 20),
            const Text(
              'টাকার খাতা',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.brand),
            ),
            const SizedBox(height: 32),
            const Text(
              'ভাষা বেছে নিন · Choose your language',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            option('bn', 'বাংলা', 'বাংলা লেখা ও বাংলা সংখ্যা (৳১,২৩৪)', '🇧🇩'),
            const SizedBox(height: 12),
            option('en', 'English', 'English text and digits (৳1,234)', '🌐'),
            const SizedBox(height: 24),
            Text(
              'পরে সেটিংস থেকে বদলানো যাবে · You can change this later in Settings',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
