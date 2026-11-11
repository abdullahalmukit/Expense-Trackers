import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repo.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb();
  await Repo(db).seedIfNeeded();
  runApp(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const TakaApp(),
    ),
  );
}
