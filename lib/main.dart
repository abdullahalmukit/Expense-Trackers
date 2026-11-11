import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repo.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb();
  // ভাষা আগে বাছাই করা থাকলে সেই ভাষায় ডিফল্ট ক্যাটাগরি; না থাকলে ভাষা বাছাইয়ের পরে
  final repo = Repo(db);
  final lang = await repo.getSetting('lang');
  if (lang != null) await repo.seedIfNeeded(en: lang == 'en');
  runApp(ProviderScope(overrides: [dbProvider.overrideWithValue(db)], child: const TakaApp()));
}
