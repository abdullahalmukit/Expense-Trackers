import 'package:drift/drift.dart';

import 'database.dart';

/// প্রথমবার খুললে কিছু ডিফল্ট ক্যাটাগরি — বাছাই করা ভাষায়। চাইলে সব মুছে ফেলা যাবে।
List<CategoriesCompanion> defaultCategories({bool en = false}) => [
  _c(en ? 'Food' : 'খাবার', '🍛', 0xFFE5533D, 0, 0),
  _c(en ? 'Transport' : 'যাতায়াত', '🚌', 0xFF1E88E5, 0, 1),
  _c(en ? 'Groceries' : 'বাজার', '🛒', 0xFF43A047, 0, 2),
  _c(en ? 'Mobile' : 'মোবাইল', '📱', 0xFF00ACC1, 0, 3),
  _c(en ? 'Education' : 'পড়াশোনা', '📚', 0xFF3949AB, 0, 4),
  _c(en ? 'Health' : 'স্বাস্থ্য', '💊', 0xFFD81B60, 0, 5),
  _c(en ? 'Debt' : 'ধার', '🤝', 0xFF7E57C2, 0, 99, debt: true),
  _c(en ? 'Tuition' : 'টিউশন', '👨‍🏫', 0xFF2E9E5B, 1, 0),
  _c(en ? 'From family' : 'পরিবার থেকে', '🏠', 0xFFF57C00, 1, 1),
  _c(en ? 'Debt' : 'ধার', '🤝', 0xFF7E57C2, 1, 99, debt: true),
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

List<WalletsCompanion> defaultWallets({bool en = false}) => [
  WalletsCompanion.insert(name: en ? 'Cash' : 'ক্যাশ', emoji: '💵', sortOrder: const Value(0)),
];
