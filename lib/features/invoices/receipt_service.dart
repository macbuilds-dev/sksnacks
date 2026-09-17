import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/tenant.dart';
import '../../core/sync/sync_worker.dart';
import '../../data/local/app_database.dart';
import '../../features/auth/auth_state.dart';

/// Human labels for bill.status values (lists / sheets).
String billStatusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Open — paisa baqi';
    case 'partial':
      return 'Partial — kuch baqi';
    case 'paid':
      return 'Paid — poora clear';
    case 'void':
      return 'Void — cancel';
    default:
      return status;
  }
}

String ownerDisplayName(String? ownerId) {
  if (ownerId == null || ownerId.isEmpty) return '—';
  for (final o in ownerPresets) {
    if (o.ownerId == ownerId) return o.displayName;
  }
  return ownerId;
}

/// One semantic mood per slip (success / danger / warning / …).
enum ReceiptMood {
  /// Cash in, payments, paid bills — green.
  income,

  /// Cash out, waste, void — red.
  expense,

  /// Open / partial udhaar — orange warning.
  due,

  /// Production / factory — lemon.
  produce,

  /// Neutral stock / transfer — mint.
  stock,

  /// Default sale — magenta.
  sale,
}

ReceiptMood moodForBillStatus(String status) {
  switch (status) {
    case 'paid':
      return ReceiptMood.income;
    case 'void':
      return ReceiptMood.expense;
    case 'partial':
    case 'open':
      return ReceiptMood.due;
    default:
      return ReceiptMood.sale;
  }
}

ReceiptMood moodForCashKind(String kind) =>
    kind == 'in' ? ReceiptMood.income : ReceiptMood.expense;

ReceiptMood moodForStockType(String type) {
  switch (type) {
    case 'purchase':
    case 'return_in':
    case 'adjust_up':
      return ReceiptMood.income;
    case 'sale':
    case 'waste':
    case 'adjust_down':
      return ReceiptMood.expense;
    case 'transfer':
      return ReceiptMood.stock;
    default:
      return ReceiptMood.stock;
  }
}

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  final String name;
  final String qty;
  final String price;
  final String total;
}

class ReceiptDraft {
  const ReceiptDraft({
    required this.id,
    required this.headline,
    this.qrPayload,
    this.meta = const [],
    this.lines = const [],
    this.totals = const [],
    this.ownerName,
    this.at,
    this.footer = 'Garam garam, hisaab garam.',
    this.mood = ReceiptMood.sale,
  });

  final String id;
  final String headline;
  final String? qrPayload;
  final List<(String, String)> meta;
  final List<ReceiptLine> lines;
  final List<(String, String)> totals;
  final String? ownerName;
  final DateTime? at;
  final String footer;
  final ReceiptMood mood;

  factory ReceiptDraft.fromBill({
    required Bill bill,
    Party? party,
    required List<BillLine> lines,
  }) {
    final money = NumberFormat('#,##0');
    final due = bill.total - bill.paid;
    return ReceiptDraft(
      id: bill.id,
      headline: 'BILL RECEIPT',
      qrPayload: bill.qrCode,
      ownerName: ownerDisplayName(bill.createdByOwnerId),
      at: bill.createdAt,
      mood: moodForBillStatus(bill.status),
      meta: [
        ('Bill No', bill.billNo ?? bill.id.substring(0, 8)),
        ('Type', bill.kind.toUpperCase()),
        ('Status', billStatusLabel(bill.status)),
        ('Party', party?.name ?? bill.partyId),
        if ((party?.phone ?? '').isNotEmpty) ('Phone', party!.phone!),
      ],
      lines: [
        for (final l in lines)
          ReceiptLine(
            name: l.description,
            qty: _qty(l.qty),
            price: money.format(l.unitPrice),
            total: money.format(l.lineTotal),
          ),
      ],
      totals: [
        if (bill.discount > 0)
          ('Discount', '- Rs ${money.format(bill.discount)}'),
        if (bill.tax > 0) ('Tax', 'Rs ${money.format(bill.tax)}'),
        ('TOTAL', 'Rs ${money.format(bill.total)}'),
        ('Paid', 'Rs ${money.format(bill.paid)}'),
        (due > 0.009 ? 'Balance due' : 'Balance', 'Rs ${money.format(due)}'),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? '${q.toInt()}' : q.toStringAsFixed(1);
}

class BillReceiptBytes {
  const BillReceiptBytes({
    required this.pngBytes,
    required this.localPngPath,
  });

  final Uint8List pngBytes;
  final String localPngPath;
}

/// Compact kitsch slip: one mood color, table rows, short height.
class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({super.key, required this.draft});

  final ReceiptDraft draft;

  static const _ink = Color(0xFF11080C);
  static const _paper = Color(0xFFFFFDF5);

  ({Color accent, Color wash, Color amount}) _palette() {
    switch (draft.mood) {
      case ReceiptMood.income:
        return (
          accent: const Color(0xFF00D4C8),
          wash: const Color(0xFF39FF14).withValues(alpha: 0.22),
          amount: const Color(0xFF0B6B12),
        );
      case ReceiptMood.expense:
        return (
          accent: const Color(0xFFFF0044),
          wash: const Color(0xFFFF0044).withValues(alpha: 0.12),
          amount: const Color(0xFFFF0044),
        );
      case ReceiptMood.due:
        return (
          accent: const Color(0xFFFF6B00),
          wash: const Color(0xFFFF6B00).withValues(alpha: 0.14),
          amount: const Color(0xFFFF6B00),
        );
      case ReceiptMood.produce:
        return (
          accent: const Color(0xFFFFE600),
          wash: const Color(0xFFFFE600).withValues(alpha: 0.28),
          amount: _ink,
        );
      case ReceiptMood.stock:
        return (
          accent: const Color(0xFF00D4C8),
          wash: const Color(0xFF00D4C8).withValues(alpha: 0.14),
          amount: _ink,
        );
      case ReceiptMood.sale:
        return (
          accent: const Color(0xFFFF2D95),
          wash: const Color(0xFFFF2D95).withValues(alpha: 0.12),
          amount: const Color(0xFFFF2D95),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy · hh:mm a');
    final p = _palette();
    final mono = GoogleFonts.robotoMono;
    final display = GoogleFonts.bangers;

    TextStyle cell({
      bool header = false,
      bool amount = false,
      double size = 17,
    }) =>
        mono(
          fontSize: size,
          fontWeight: header || amount ? FontWeight.w700 : FontWeight.w500,
          color: amount ? p.amount : _ink,
          height: 1.2,
        );

    Widget tableBox({required List<Widget> children}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.wash,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ink, width: 2.5),
        ),
        child: Column(children: children),
      );
    }

    Widget kvRow(String left, String right, {bool amount = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 36,
              child: Text(
                left,
                style: cell(size: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 64,
              child: Text(
                right,
                style: cell(amount: amount, size: amount ? 18 : 17),
                textAlign: TextAlign.right,
                maxLines: 2,
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    }

    Widget detailHeader() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              flex: 40,
              child: Text('Item', style: cell(header: true, size: 16)),
            ),
            Expanded(
              flex: 10,
              child: Text(
                'Qty',
                style: cell(header: true, size: 16),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                'Price',
                style: cell(header: true, size: 16),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 30,
              child: Text(
                'Total',
                style: cell(header: true, size: 16),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    Widget detailRow(ReceiptLine line) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 40,
              child: Text(
                line.name,
                style: cell(size: 17),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                line.qty,
                style: cell(size: 17),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                line.price,
                style: cell(amount: true, size: 17),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 30,
              child: Text(
                line.total,
                style: cell(amount: true, size: 17),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    bool isAmountKey(String k) {
      final lower = k.toLowerCase();
      return lower.contains('total') ||
          lower.contains('paid') ||
          lower.contains('balance') ||
          lower.contains('amount') ||
          lower.contains('discount') ||
          lower.contains('tax') ||
          lower.contains('tayyar') ||
          lower.contains('baqaya');
    }

    return ColoredBox(
      color: _paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            color: p.accent,
            child: Column(
              children: [
                Text(
                  'SHSNACKS',
                  textAlign: TextAlign.center,
                  style: display(fontSize: 42, color: _ink, letterSpacing: 1.2),
                ),
                Text(
                  draft.headline,
                  textAlign: TextAlign.center,
                  style: mono(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (draft.qrPayload != null && draft.qrPayload!.isNotEmpty) ...[
                  Center(
                    child: QrImageView(
                      data: draft.qrPayload!,
                      size: 130,
                      backgroundColor: _paper,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: _ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: _ink,
                      ),
                    ),
                  ),
                  Text(
                    draft.qrPayload!,
                    textAlign: TextAlign.center,
                    style: mono(fontSize: 14, color: _ink),
                  ),
                  const SizedBox(height: 10),
                ],
                tableBox(
                  children: [
                    if (draft.at != null)
                      kvRow('Date', dateFmt.format(draft.at!.toLocal())),
                    if (draft.ownerName != null && draft.ownerName!.isNotEmpty)
                      kvRow('By owner', draft.ownerName!),
                    for (final m in draft.meta)
                      kvRow(m.$1, m.$2, amount: isAmountKey(m.$1)),
                  ],
                ),
                if (draft.lines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  tableBox(
                    children: [
                      detailHeader(),
                      Divider(
                        height: 8,
                        thickness: 1.5,
                        color: _ink.withValues(alpha: 0.35),
                      ),
                      for (final l in draft.lines) detailRow(l),
                    ],
                  ),
                ],
                if (draft.totals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  tableBox(
                    children: [
                      for (final t in draft.totals)
                        kvRow(t.$1, t.$2, amount: true),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Shukriya!',
                  textAlign: TextAlign.center,
                  style: display(fontSize: 34, color: p.accent),
                ),
                Text(
                  draft.footer,
                  textAlign: TextAlign.center,
                  style: mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptService {
  ReceiptService(this.db);

  final AppDatabase db;

  Future<BillReceiptBytes> captureAndStore({
    required GlobalKey boundaryKey,
    required String fileId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Receipt not ready to capture');
    }
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw StateError('Could not encode receipt');
    final bytes = byteData.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(dir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    final pngPath = p.join(receiptsDir.path, '$fileId.png');
    await File(pngPath).writeAsBytes(bytes, flush: true);

    return BillReceiptBytes(pngBytes: bytes, localPngPath: pngPath);
  }

  Future<void> saveToGallery(BillReceiptBytes receipt, String name) async {
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) throw StateError('Gallery permission denied');
    }
    await Gal.putImageBytes(receipt.pngBytes, name: 'SH_$name');
  }

  Future<void> syncMeta(
    String collection,
    String docId,
    BillReceiptBytes receipt,
  ) async {
    String? remoteUrl;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child(tenantStoragePath('receipts'))
          .child('$docId.png');
      await ref.putData(
        receipt.pngBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      remoteUrl = await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Receipt upload failed: $e');
    }

    await enqueueSync(
      db,
      collection: collection,
      docId: docId,
      payload: {
        'receiptLocalPng': receipt.localPngPath,
        'receiptRemoteUrl': ?remoteUrl,
        'receiptSavedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> share(BillReceiptBytes receipt, {String? label}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            receipt.localPngPath,
            mimeType: 'image/png',
            name: 'SH_receipt_${label ?? 'slip'}.png',
          ),
        ],
        text: 'SHSnacks receipt',
      ),
    );
  }
}
