import 'package:drift/drift.dart';

import 'database.dart';

/// প্রথমবার খুললে কিছু ডিফল্ট ক্যাটাগরি — চাইলে সব মুছে ফেলা যাবে।
final defaultCategories = <CategoriesCompanion>[
  _c('খাবার', '🍛', 0xFFE5533D, 0, 0),
  _c('যাতায়াত', '🚌', 0xFF1E88E5, 0, 1),
  _c('বাজার', '🛒', 0xFF43A047, 0, 2),
  _c('মোবাইল', '📱', 0xFF00ACC1, 0, 3),
  _c('পড়াশোনা', '📚', 0xFF3949AB, 0, 4),
  _c('স্বাস্থ্য', '💊', 0xFFD81B60, 0, 5),
  _c('ধার', '🤝', 0xFF7E57C2, 0, 99, debt: true),
  _c('টিউশন', '👨‍🏫', 0xFF2E9E5B, 1, 0),
  _c('পরিবার থেকে', '🏠', 0xFFF57C00, 1, 1),
  _c('ধার', '🤝', 0xFF7E57C2, 1, 99, debt: true),
];

CategoriesCompanion _c(
  String name,
  String emoji,
  int color,
  int kind,
  int order, {
  bool debt = false,
}) => CategoriesCompanion.insert(
  name: name,
  emoji: emoji,
  color: color,
  kind: kind,
  sortOrder: Value(order),
  isDebt: Value(debt),
);

final defaultWallets = <WalletsCompanion>[
  WalletsCompanion.insert(name: 'ক্যাশ', emoji: '💵', sortOrder: const Value(0)),
];
