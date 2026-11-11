import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;

import '../core/dates.dart';
import '../core/money.dart';
import '../data/database.dart';
import '../domain/finance.dart';

/// CSV/Excel-এর কলাম। ইমপোর্টের সময় এই বাংলা নাম বা ইংরেজি alias দুটোই চেনা হয়।
class Cols {
  static const id = 'ID';
  static const date = 'তারিখ';
  static const type = 'ধরন';
  static const amount = 'টাকা';
  static const category = 'ক্যাটাগরি';
  static const emoji = 'ইমোজি';
  static const debt = 'ধার';
  static const person = 'ব্যক্তি';
  static const wallet = 'ওয়ালেট';
  static const note = 'বিবরণ';
  static const purpose = 'উদ্দেশ্য';
  static const due = 'ফেরতের তারিখ';

  static const all = [id, date, type, amount, category, emoji, debt, person, wallet, note, purpose, due];

  static const aliases = <String, List<String>>{
    id: ['id', 'uuid'],
    date: ['date', 'datetime', 'occurred_at', 'time', 'সময়'],
    type: ['type', 'kind'],
    amount: ['amount', 'taka', 'পরিমাণ'],
    category: ['category', 'cat'],
    emoji: ['emoji', 'icon'],
    debt: ['debt', 'debt_action', 'ধারের ধরন'],
    person: ['person', 'name', 'নাম'],
    wallet: ['wallet', 'account', 'একাউন্ট'],
    note: ['note', 'description', 'details', 'নোট'],
    purpose: ['purpose', 'উদ্দেশ্য'],
    due: ['due', 'due_date', 'শোধের তারিখ'],
  };

  /// হেডার সারি থেকে কলাম ইনডেক্স
  static Map<String, int> resolve(List<String> header) {
    final out = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final h = header[i].trim().replaceAll('﻿', '');
      final hl = h.toLowerCase();
      for (final c in all) {
        if (out.containsKey(c)) continue;
        if (h == c || aliases[c]!.contains(hl)) {
          out[c] = i;
          break;
        }
      }
    }
    return out;
  }
}

String _taka(int paisa) => paisaToPlain(paisa);

List<String> _rowFor(Txn t, FinanceData fin) => [
  t.id,
  isoDateTime(t.occurredAt),
  TxType.label(t.type),
  _taka(t.amount),
  fin.catById[t.categoryId]?.name ?? '',
  fin.catById[t.categoryId]?.emoji ?? '',
  t.debtAction == null ? '' : DebtAction.label(t.debtAction!),
  t.personId == null ? '' : (fin.personById[t.personId]?.name ?? ''),
  t.walletId == null ? '' : (fin.walletById[t.walletId]?.name ?? ''),
  t.note,
  t.purpose,
  t.dueDate == null ? '' : isoDate(t.dueDate!),
];

List<Txn> _txnsIn(FinanceData fin, DateRange? r) {
  final list = r == null ? [...fin.txns] : fin.inRange(r).toList();
  list.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  return list;
}

class Exporter {
  /// প্রতি সারিতে একটি এন্ট্রি (UTF-8 BOM সহ, যাতে Excel-এ বাংলা ঠিক দেখায়)
  static Uint8List csvBytes(FinanceData fin, DateRange? r) {
    final rows = <List<dynamic>>[
      Cols.all,
      for (final t in _txnsIn(fin, r)) _rowFor(t, fin),
    ];
    final s = Csv(lineDelimiter: '\r\n').encode(rows);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(s)]);
  }

  /// আলাদা শিট: এন্ট্রি, মাসিক সারাংশ, ক্যাটাগরি, ধার
  static Uint8List xlsxBytes(FinanceData fin, DateRange? r) {
    final book = xl.Excel.createExcel();
    final defaultName = book.getDefaultSheet() ?? 'Sheet1';
    xl.CellValue? cv(Object? v) {
      if (v == null) return null;
      if (v is int) return xl.IntCellValue(v);
      if (v is double) return xl.DoubleCellValue(v);
      return xl.TextCellValue('$v');
    }

    final bold = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#FFCF4A'));
    void header(xl.Sheet s, List<String> h) {
      s.appendRow([for (final x in h) xl.TextCellValue(x)]);
      for (var i = 0; i < h.length; i++) {
        s.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = bold;
      }
    }

    // এন্ট্রি
    final txns = _txnsIn(fin, r);
    final s1 = book['এন্ট্রি'];
    header(s1, Cols.all);
    for (final t in txns) {
      final row = _rowFor(t, fin);
      s1.appendRow([
        for (var i = 0; i < row.length; i++)
          i == 3 ? xl.DoubleCellValue(t.amount / 100) : cv(row[i]),
      ]);
    }

    // মাসিক সারাংশ
    final s2 = book['মাসিক সারাংশ'];
    header(s2, ['মাস', 'শুরুর ব্যালেন্স', 'মোট জমা', 'মোট খরচ', 'ধার ছাড়া জমা', 'ধার ছাড়া খরচ', 'মাস শেষের ব্যালেন্স']);
    final months = r?.months ??
        (txns.isEmpty
            ? <DateTime>[]
            : DateRange(monthStart(txns.first.occurredAt), nextMonth(monthStart(txns.last.occurredAt))).months);
    for (final m in months) {
      final s = fin.monthSummary(m);
      s2.appendRow([
        xl.TextCellValue(monthKey(m)),
        for (final v in [s.opening, s.income, s.expense, s.realIncome, s.realExpense, s.closing])
          xl.DoubleCellValue(v / 100),
      ]);
    }

    // ক্যাটাগরি
    final s3 = book['ক্যাটাগরি'];
    header(s3, ['নাম', 'ইমোজি', 'ধরন', 'রং', 'ক্রম', 'আর্কাইভ', 'ধার', 'মোট (এই পরিসরে)']);
    final range = r ?? DateRange(DateTime(1970), DateTime(3000));
    final tExp = fin.categoryTotals(range, TxType.expense);
    final tInc = fin.categoryTotals(range, TxType.income);
    for (final c in fin.cats) {
      s3.appendRow([
        xl.TextCellValue(c.name),
        xl.TextCellValue(c.emoji),
        xl.TextCellValue(TxType.label(c.kind)),
        xl.TextCellValue('#${(c.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'),
        xl.IntCellValue(c.sortOrder),
        xl.TextCellValue(c.archived ? 'হ্যাঁ' : 'না'),
        xl.TextCellValue(c.isDebt ? 'হ্যাঁ' : 'না'),
        xl.DoubleCellValue(((c.kind == 0 ? tExp : tInc)[c.id] ?? 0) / 100),
      ]);
    }

    // ধার
    final s4 = book['ধার'];
    header(s4, ['ব্যক্তি', 'নিয়েছি', 'শোধ করেছি', 'আমি দেব', 'দিয়েছি', 'ফেরত পেয়েছি', 'আমি পাব']);
    for (final d in fin.debts()) {
      s4.appendRow([
        xl.TextCellValue(d.person.name),
        for (final v in [d.borrowed, d.repaid, d.payable, d.lent, d.collected, d.receivable])
          xl.DoubleCellValue(v / 100),
      ]);
    }

    if (defaultName != 'এন্ট্রি') book.delete(defaultName);
    book.setDefaultSheet('এন্ট্রি');
    return Uint8List.fromList(book.encode()!);
  }

  /// Word (.docx) রিপোর্ট — এডিটযোগ্য
  static Uint8List docxBytes(FinanceData fin, DateRange? r) {
    final d = _Docx();
    final txns = _txnsIn(fin, r);
    final months = r?.months ??
        (txns.isEmpty
            ? <DateTime>[]
            : DateRange(monthStart(txns.first.occurredAt), nextMonth(monthStart(txns.last.occurredAt))).months);
    d.para('টাকার খাতা — হিসাবের রিপোর্ট', size: 36, bold: true, color: '23308C');
    d.para(r == null ? 'সব সময়ের হিসাব' : r.label, size: 24, color: '555555');
    d.para('তৈরি: ${dateTimeLabel(DateTime.now())}', size: 18, color: '888888');

    for (final m in months) {
      final range = DateRange.month(m);
      final list = txns.where((t) => range.contains(t.occurredAt)).toList();
      if (list.isEmpty && months.length > 1) continue;
      final s = fin.monthSummary(m);
      d.para(monthLabel(m), size: 30, bold: true, color: '23308C', spaceBefore: 360);
      d.table(
        ['বিষয়', 'টাকা'],
        [
          ['শুরুর ব্যালেন্স', money(s.opening)],
          ['মোট জমা (ধার সহ)', money(s.income)],
          ['মোট খরচ (ধার সহ)', money(s.expense)],
          ['ধার ছাড়া আসল জমা', money(s.realIncome)],
          ['ধার ছাড়া আসল খরচ', money(s.realExpense)],
          ['মাস শেষের ব্যালেন্স', money(s.closing)],
        ],
        widths: [5000, 3000],
      );
      final cats = fin.categoryTotals(range, TxType.expense).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (cats.isNotEmpty) {
        final total = cats.fold(0, (x, e) => x + e.value);
        d.para('ক্যাটাগরি অনুযায়ী খরচ', size: 24, bold: true, spaceBefore: 240);
        d.table(
          ['ক্যাটাগরি', 'টাকা', 'ভাগ'],
          [
            for (final e in cats)
              [
                '${fin.catById[e.key]?.emoji ?? ''} ${fin.catById[e.key]?.name ?? ''}',
                money(e.value),
                percent(e.value / total * 100),
              ],
          ],
          widths: [4500, 2500, 1500],
        );
      }
      if (list.isNotEmpty) {
        d.para('এন্ট্রির তালিকা', size: 24, bold: true, spaceBefore: 240);
        d.table(
          ['তারিখ', 'ক্যাটাগরি', 'বিবরণ', 'জমা', 'খরচ'],
          [
            for (final t in list)
              [
                '${dayLabel(t.occurredAt)} ${timeLabel(t.occurredAt)}',
                [
                  fin.catById[t.categoryId]?.name ?? '',
                  if (t.debtAction != null) '(${DebtAction.label(t.debtAction!)}${t.personId != null ? ' · ${fin.personById[t.personId]?.name ?? ''}' : ''})',
                ].join(' '),
                [t.note, t.purpose].where((x) => x.isNotEmpty).join(' · '),
                t.type == TxType.income ? money(t.amount) : '',
                t.type == TxType.expense ? money(t.amount) : '',
              ],
          ],
          widths: [2000, 2200, 2600, 1300, 1300],
          small: true,
        );
      }
    }
    final debts = fin.debts().where((x) => !x.settled).toList();
    if (debts.isNotEmpty) {
      d.para('বাকি ধার (আজ পর্যন্ত)', size: 28, bold: true, color: '7E57C2', spaceBefore: 360);
      d.table(
        ['ব্যক্তি', 'আমি দেব', 'আমি পাব'],
        [for (final x in debts) [x.person.name, money(x.payable), money(x.receivable)]],
        widths: [4000, 2200, 2200],
      );
    }
    return d.build();
  }
}

/// ছোট .docx নির্মাতা (WordprocessingML) — বাড়তি টেমপ্লেট ফাইল লাগে না
class _Docx {
  final _body = StringBuffer();

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _run(String text, {int size = 22, bool bold = false, String? color}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Noto Sans Bengali" w:hAnsi="Noto Sans Bengali" w:cs="Nirmala UI"/>'
      '${bold ? '<w:b/><w:bCs/>' : ''}${color != null ? '<w:color w:val="$color"/>' : ''}'
      '<w:sz w:val="$size"/><w:szCs w:val="$size"/><w:lang w:bidi="bn-BD"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r>';

  void para(String text, {int size = 22, bool bold = false, String? color, int spaceBefore = 0}) {
    _body.write(
      '<w:p><w:pPr><w:spacing w:before="$spaceBefore" w:after="120"/></w:pPr>'
      '${_run(text, size: size, bold: bold, color: color)}</w:p>',
    );
  }

  void table(List<String> head, List<List<String>> rows, {required List<int> widths, bool small = false}) {
    final sz = small ? 18 : 21;
    String cell(String t, int w, {bool header = false, bool right = false}) =>
        '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/>'
        '${header ? '<w:shd w:val="clear" w:color="auto" w:fill="FFCF4A"/>' : ''}</w:tcPr>'
        '<w:p><w:pPr><w:spacing w:before="40" w:after="40"/>${right ? '<w:jc w:val="right"/>' : ''}</w:pPr>'
        '${_run(t, size: sz, bold: header)}</w:p></w:tc>';
    bool isMoney(String s) => s.startsWith('৳') || s.startsWith('-৳') || s.endsWith('%');
    _body.write(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>'
      '${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((b) => '<w:$b w:val="single" w:sz="4" w:space="0" w:color="BBBBBB"/>').join()}'
      '</w:tblBorders><w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr>'
      '<w:tblGrid>${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>'
      '<w:tr><w:trPr><w:tblHeader/></w:trPr>${[for (var i = 0; i < head.length; i++) cell(head[i], widths[i], header: true)].join()}</w:tr>'
      '${rows.map((r) => '<w:tr>${[for (var i = 0; i < r.length; i++) cell(r[i], widths[i], right: isMoney(r[i]))].join()}</w:tr>').join()}'
      '</w:tbl>',
    );
    _body.write('<w:p/>');
  }

  Uint8List build() {
    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
    final doc =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$_body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="500" w:footer="500" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', doc);
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }
}
