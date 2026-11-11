import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../providers.dart';
import '../../services/backup.dart';
import '../../services/exporter.dart';
import '../../services/files.dart';
import '../../services/importer.dart';
import '../../services/report.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

enum ExportFormat { json, xlsx, csv, pdf, docx }

extension on ExportFormat {
  String get label => switch (this) {
    ExportFormat.json => tr('JSON (পূর্ণ ব্যাকআপ)', 'JSON (full backup)'),
    ExportFormat.xlsx => 'Excel (.xlsx)',
    ExportFormat.csv => 'CSV',
    ExportFormat.pdf => tr('PDF রিপোর্ট', 'PDF report'),
    ExportFormat.docx => 'Word (.docx)',
  };
  String get desc => switch (this) {
    ExportFormat.json => tr(
      'সব এন্ট্রি, ক্যাটাগরি, ব্যক্তি, ওয়ালেট, বাজেট, সেটিংস — হুবহু ফেরত আনা যায়',
      'All entries, categories, people, wallets, budgets, settings — restores exactly',
    ),
    ExportFormat.xlsx => tr(
      'আলাদা শিট: এন্ট্রি, মাসিক সারাংশ, ক্যাটাগরি, ধার — আবার ইমপোর্ট করা যায়',
      'Separate sheets: entries, monthly summary, categories, debts — can be imported back',
    ),
    ExportFormat.csv => tr(
      'প্রতি সারিতে একটি এন্ট্রি — আবার ইমপোর্ট করা যায়',
      'One entry per row — can be imported back',
    ),
    ExportFormat.pdf => tr(
      'মাসিক রিপোর্ট — সারাংশ, চার্ট, তালিকা (পড়া ও প্রিন্টের জন্য)',
      'Monthly report — summary, charts, list (for reading and printing)',
    ),
    ExportFormat.docx => tr('PDF-এর মতো রিপোর্ট, এডিটযোগ্য', 'Report like the PDF, editable'),
  };
  String get ext => switch (this) {
    ExportFormat.json => 'json',
    ExportFormat.xlsx => 'xlsx',
    ExportFormat.csv => 'csv',
    ExportFormat.pdf => 'pdf',
    ExportFormat.docx => 'docx',
  };
  IconData get icon => switch (this) {
    ExportFormat.json => Icons.data_object,
    ExportFormat.xlsx => Icons.grid_on,
    ExportFormat.csv => Icons.table_rows_outlined,
    ExportFormat.pdf => Icons.picture_as_pdf_outlined,
    ExportFormat.docx => Icons.description_outlined,
  };
}

/// এক্সপোর্ট: আগে রেঞ্জ (এক মাস, কয়েক মাস, সব), তারপর ফরম্যাট
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _mode = 'month'; // month | months | all
  late DateTime _from = monthStart(DateTime.now());
  late DateTime _to = monthStart(DateTime.now());
  ExportFormat _format = ExportFormat.pdf;
  bool _busy = false;

  DateRange? get _range => switch (_mode) {
    'month' => DateRange.month(_from),
    'months' => DateRange(
      monthStart(_from.isBefore(_to) ? _from : _to),
      nextMonth(_from.isBefore(_to) ? _to : _from),
    ),
    _ => null,
  };

  String get _fileName {
    final r = _range;
    final part = r == null
        ? 'all'
        : (_mode == 'month'
              ? monthKey(r.start)
              : '${monthKey(r.start)}_to_${monthKey(r.end.subtract(const Duration(days: 1)))}');
    return 'takar-khata-$part-${isoDate(DateTime.now())}.${_format.ext}';
  }

  Future<List<int>> _bytes() async {
    final fin = ref.read(financeProvider);
    final r = _range;
    return switch (_format) {
      ExportFormat.json => await Backup.bytes(ref.read(dbProvider), range: r),
      ExportFormat.csv => Exporter.csvBytes(fin, r),
      ExportFormat.xlsx => Exporter.xlsxBytes(fin, r),
      ExportFormat.docx => Exporter.docxBytes(fin, r),
      ExportFormat.pdf => await PdfReport.build(fin, r),
    };
  }

  Future<void> _run(String action) async {
    setState(() => _busy = true);
    try {
      final data = await _bytes();
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      final name = _fileName;
      final mime = Files.mimeFor(name);
      switch (action) {
        case 'save':
          final f = await Files.saveToDownloads(name, bytes);
          if (mounted) {
            toast(
              context,
              tr(
                'সেভ হয়েছে: ${f.path.replaceFirst('/storage/emulated/0/', '')}',
                'Saved: ${f.path.replaceFirst('/storage/emulated/0/', '')}',
              ),
            );
          }
        case 'saveas':
          final ok = await Files.saveAs(name, bytes, mime);
          if (mounted && ok) toast(context, tr('সেভ হয়েছে', 'Saved'));
        case 'share':
          await Files.share(name, bytes, mime);
        case 'print':
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e) {
      if (mounted) toast(context, tr('এক্সপোর্ট হয়নি: $e', 'Export failed: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = ref.watch(financeProvider);
    final r = _range;
    final count = r == null ? fin.txns.length : fin.inRange(r).length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('এক্সপোর্ট', 'Export'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            tr('১. কোন সময়ের?', '1. Which period?'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'month', label: Text(tr('এক মাস', 'One month'))),
              ButtonSegment(value: 'months', label: Text(tr('কয়েক মাস', 'Several months'))),
              ButtonSegment(value: 'all', label: Text(tr('সব', 'All'))),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          if (_mode != 'all')
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(monthLabel(_from)),
                  onPressed: () async {
                    final m = await showMonthPicker(context, _from);
                    if (m != null) setState(() => _from = m);
                  },
                ),
                if (_mode == 'months') ...[
                  Text(tr('থেকে', 'to')),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: Text(monthLabel(_to)),
                    onPressed: () async {
                      final m = await showMonthPicker(context, _to);
                      if (m != null) setState(() => _to = m);
                    },
                  ),
                  Text(tr('পর্যন্ত', '')),
                ],
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr(
                '${r?.label ?? 'সব সময়'} · ${dg(count)}টি এন্ট্রি',
                '${r?.label ?? 'All time'} · ${dg(count)} entries',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('২. ফরম্যাট', '2. Format'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          RadioGroup<ExportFormat>(
            groupValue: _format,
            onChanged: (v) => setState(() => _format = v!),
            child: Column(
              children: [
                for (final f in ExportFormat.values)
                  RadioListTile<ExportFormat>(
                    value: f,
                    secondary: Icon(f.icon),
                    title: Text(f.label),
                    subtitle: Text(f.desc, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run('save'),
            icon: const Icon(Icons.download),
            label: Text(tr('Downloads-এ সেভ করুন', 'Save to Downloads')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run('share'),
                  icon: const Icon(Icons.share),
                  label: Text(tr('শেয়ার', 'Share')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run('saveas'),
                  icon: const Icon(Icons.folder_open),
                  label: Text(tr('অন্য জায়গায়', 'Save as…')),
                ),
              ),
              if (_format == ExportFormat.pdf) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: tr('প্রিন্ট', 'Print'),
                  onPressed: _busy ? null : () => _run('print'),
                  icon: const Icon(Icons.print),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ইমপোর্ট: ফাইল → প্রিভিউ → মিলিয়ে যোগ / সব বদলে দিন
Future<void> startImport(BuildContext context, WidgetRef ref, {File? file}) async {
  String name;
  Uint8List bytes;
  if (file != null) {
    name = p.basename(file.path);
    bytes = await file.readAsBytes();
  } else {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'xlsx', 'csv'],
    );
    if (picked.isEmpty) return;
    final f = picked.first;
    name = f.name;
    bytes = await f.readAsBytes();
  }
  if (!context.mounted) return;
  final ImportBundle bundle;
  try {
    bundle = Importer.parse(name, bytes);
  } catch (e) {
    toast(
      context,
      e is FormatException ? e.message : tr('ফাইল পড়া যায়নি: $e', 'Could not read the file: $e'),
    );
    return;
  }
  final repo = ref.read(repoProvider);
  final preview = await Importer.preview(repo, bundle);
  if (!context.mounted) return;
  final months = bundle.monthCounts;
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(tr('ইমপোর্ট প্রিভিউ', 'Import preview'), style: Theme.of(ctx).textTheme.titleLarge),
          Text(name, style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
          const SizedBox(height: 12),
          StatLine(tr('মোট এন্ট্রি', 'Total entries'), dg(preview.total), bold: true),
          StatLine(
            tr('আগে থেকেই আছে (ডুপ্লিকেট)', 'Already present (duplicates)'),
            dg(preview.duplicates),
          ),
          StatLine(
            tr('নতুন যোগ হবে (মিলিয়ে যোগে)', 'Will be added (when merging)'),
            dg(preview.total - preview.duplicates),
          ),
          if (preview.newCategories.isNotEmpty)
            StatLine(
              tr('নতুন ক্যাটাগরি তৈরি হবে', 'New categories to create'),
              preview.newCategories.take(4).join(', ') +
                  (preview.newCategories.length > 4 ? '…' : ''),
            ),
          if (preview.newPersons.isNotEmpty)
            StatLine(
              tr('নতুন ব্যক্তি তৈরি হবে', 'New people to create'),
              preview.newPersons.take(4).join(', ') + (preview.newPersons.length > 4 ? '…' : ''),
            ),
          if (bundle.isFullBackup)
            StatLine(
              tr('ধরন', 'Type'),
              tr(
                'পূর্ণ ব্যাকআপ (ক্যাটাগরি, ওয়ালেট, বাজেট, সেটিংস সহ)',
                'Full backup (with categories, wallets, budgets, settings)',
              ),
            ),
          if (bundle.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tr(
                '⚠️ ${dg(bundle.warnings.length)}টি সারি বাদ পড়েছে',
                '⚠️ ${dg(bundle.warnings.length)} rows skipped',
              ),
              style: const TextStyle(color: Colors.orange),
            ),
            for (final w in bundle.warnings.take(3)) Text(w, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Text(tr('কোন কোন মাস', 'Months in file'), style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final e in months.entries.take(24))
                Chip(label: Text('${monthLabel(parseMonthKey(e.key))} · ${dg(e.value)}')),
              if (months.length > 24)
                Chip(
                  label: Text(
                    tr('+${dg(months.length - 24)} মাস', '+${dg(months.length - 24)} months'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            icon: const Icon(Icons.merge),
            label: Text(tr('মিলিয়ে যোগ করুন', 'Merge')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'প্রতিটি এন্ট্রির ইউনিক ID দেখে ডুপ্লিকেট বাদ যাবে',
              'Duplicates are skipped using each entry\'s unique ID',
            ),
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            icon: const Icon(Icons.restore),
            label: Text(tr('সব বদলে দিন', 'Replace everything')),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'বদলানোর আগে অ্যাপ নিজে একটি সুরক্ষা-ব্যাকআপ রেখে দেবে',
              'A safety backup is saved automatically before replacing',
            ),
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'replace' &&
      !await confirm(
        context,
        tr('সব বদলে দেবেন?', 'Replace everything?'),
        body: tr(
          'বর্তমান সব এন্ট্রি মুছে ফাইলের ডাটা বসবে। আগে একটি সুরক্ষা-ব্যাকআপ রাখা হবে।',
          'All current entries will be removed and replaced with the file\'s data. A safety backup is saved first.',
        ),
        ok: tr('বদলে দিন', 'Replace'),
        danger: true,
      )) {
    return;
  }
  try {
    final n = choice == 'merge'
        ? await Importer.merge(repo, bundle)
        : await Importer.replace(repo, bundle);
    ref.read(effectsProvider).refreshWidget();
    if (context.mounted) {
      toast(context, tr('${dg(n)}টি এন্ট্রি ইমপোর্ট হয়েছে ✓', '${dg(n)} entries imported ✓'));
    }
  } catch (e) {
    if (context.mounted) toast(context, tr('ইমপোর্ট হয়নি: $e', 'Import failed: $e'));
  }
}

/// অটো ব্যাকআপের তালিকা — যেকোনোটি থেকে ফেরত আনা যায়
class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});
  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  late Future<List<File>> _files = Backup.listBackups();
  String? _dir;

  @override
  void initState() {
    super.initState();
    Files.publicDir('backups').then((d) => mounted ? setState(() => _dir = d.path) : null);
  }

  void _reload() => setState(() => _files = Backup.listBackups());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('ব্যাকআপ', 'Backups'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Backup.writeToBackupFolder(ref.read(dbProvider), prefix: 'manual');
          await ref.read(repoProvider).setSetting('last_backup', DateTime.now().toIso8601String());
          _reload();
          if (context.mounted) toast(context, tr('ব্যাকআপ নেওয়া হয়েছে ✓', 'Backup saved ✓'));
        },
        icon: const Icon(Icons.backup_outlined),
        label: Text(tr('এখনই ব্যাকআপ', 'Back up now')),
      ),
      body: FutureBuilder<List<File>>(
        future: _files,
        builder: (context, snap) {
          final files = snap.data ?? const <File>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              if (_dir != null)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    tr(
                      'ফোল্ডার: ${_dir!.replaceFirst('/storage/emulated/0/', '')}\nঅ্যাপ মুছে গেলে বা ফোন বদলালেও এই ফাইল থেকে সব ফেরত আনা যাবে (সেটিংস → ইমপোর্ট)।',
                      'Folder: ${_dir!.replaceFirst('/storage/emulated/0/', '')}\nEven if the app is removed or you change phones, everything can be restored from these files (Settings → Import).',
                    ),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              if (files.isEmpty && snap.connectionState == ConnectionState.done)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text(tr('এখনও কোনো ব্যাকআপ নেই', 'No backups yet'))),
                ),
              for (final f in files)
                ListTile(
                  leading: Icon(
                    p.basename(f.path).contains('safety')
                        ? Icons.shield_outlined
                        : Icons.description_outlined,
                  ),
                  title: Text(p.basename(f.path), style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${dateTimeLabel(f.lastModifiedSync())} · ${dg((f.lengthSync() / 1024).ceil())} KB',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'restore') {
                        await startImport(context, ref, file: f);
                      } else if (v == 'share') {
                        await Files.share(
                          p.basename(f.path),
                          await f.readAsBytes(),
                          'application/json',
                        );
                      } else if (v == 'delete') {
                        await f.delete();
                        _reload();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'restore',
                        child: Text(tr('এখান থেকে ফেরত আনুন', 'Restore from this')),
                      ),
                      PopupMenuItem(value: 'share', child: Text(tr('শেয়ার', 'Share'))),
                      PopupMenuItem(value: 'delete', child: Text(tr('মুছুন', 'Delete'))),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
