/// দুই ভাষা: বাংলা ও English।
/// প্রতিটি লেখা `tr('বাংলা', 'English')` আকারে — দুটো পাশাপাশি থাকে বলে
/// কোড পড়তে সহজ, আর নোটিফিকেশন/রিপোর্টের মতো context ছাড়া জায়গাতেও চলে।
library;

class Lang {
  /// সেটিংস থেকে সেট হয় (settings['lang'] == 'en')
  static bool en = false;
  static String get code => en ? 'en' : 'bn';
}

String tr(String bn, String en) => Lang.en ? en : bn;

/// ডিফল্ট ক্যাটাগরি ও ওয়ালেটের নাম (বাংলা, English)।
/// ভাষা বদলালে যেগুলোর নাম ব্যবহারকারী বদলাননি সেগুলোও নতুন ভাষায় বদলে যায়।
const defaultNamePairs = <(String, String)>[
  ('খাবার', 'Food'),
  ('যাতায়াত', 'Transport'),
  ('বাজার', 'Groceries'),
  ('মোবাইল', 'Mobile'),
  ('পড়াশোনা', 'Education'),
  ('স্বাস্থ্য', 'Health'),
  ('ধার', 'Debt'),
  ('টিউশন', 'Tuition'),
  ('পরিবার থেকে', 'From family'),
  ('অন্যান্য', 'Others'),
  ('ক্যাশ', 'Cash'),
];
