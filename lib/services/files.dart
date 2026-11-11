import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ফাইল সেভ (ফোনের Downloads/TakarKhata), শেয়ার, আর নিজে জায়গা বেছে সেভ।
class Files {
  static const folderName = 'TakarKhata';

  /// Download/TakarKhata/[sub] — লেখা না গেলে অ্যাপের নিজস্ব ফোল্ডার
  static Future<Directory> publicDir([String sub = '']) async {
    if (!kIsWeb && Platform.isAndroid) {
      final d = Directory(p.join('/storage/emulated/0/Download', folderName, sub));
      try {
        await d.create(recursive: true);
        final probe = File(p.join(d.path, '.probe'));
        await probe.writeAsString('ok');
        await probe.delete();
        return d;
      } catch (_) {}
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final d2 = Directory(p.join(ext.path, sub));
        await d2.create(recursive: true);
        return d2;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final d3 = Directory(p.join(docs.path, folderName, sub));
    await d3.create(recursive: true);
    return d3;
  }

  static Future<File> saveToDownloads(String name, Uint8List bytes) async {
    final dir = await publicDir();
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<File> writeTemp(String name, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> share(String name, Uint8List bytes, String mime, {String? text}) async {
    final f = await writeTemp(name, bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path, mimeType: mime)], text: text, subject: name),
    );
  }

  /// সিস্টেমের "সেভ করুন" ডায়ালগ — যেকোনো ফোল্ডারে
  static Future<bool> saveAs(String name, Uint8List bytes, String mime) async {
    final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
    return uri != null;
  }

  static String mimeFor(String name) => switch (p.extension(name).toLowerCase()) {
    '.json' => 'application/json',
    '.csv' => 'text/csv',
    '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.pdf' => 'application/pdf',
    '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
