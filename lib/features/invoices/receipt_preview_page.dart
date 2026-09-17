import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/repo_providers.dart';
import 'receipt_service.dart';

Future<void> openBillReceipt(
  BuildContext context,
  WidgetRef ref,
  Bill bill,
) async {
  final khata = ref.read(khataRepoProvider);
  final party = await khata.partyById(bill.partyId);
  final lines = await khata.linesFor(bill.id);
  if (!context.mounted) return;
  final draft = ReceiptDraft.fromBill(bill: bill, party: party, lines: lines);
  await openReceiptPreview(context, draft, syncCollection: 'bills');
}

Future<void> openReceiptPreview(
  BuildContext context,
  ReceiptDraft draft, {
  String syncCollection = 'receipts',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReceiptPreviewPage(
        draft: draft,
        syncCollection: syncCollection,
      ),
      fullscreenDialog: true,
    ),
  );
}

class ReceiptPreviewPage extends ConsumerStatefulWidget {
  const ReceiptPreviewPage({
    super.key,
    required this.draft,
    this.syncCollection = 'receipts',
  });

  final ReceiptDraft draft;
  final String syncCollection;

  @override
  ConsumerState<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends ConsumerState<ReceiptPreviewPage> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  ReceiptService get _svc => ReceiptService(ref.read(appDatabaseProvider));

  Future<BillReceiptBytes> _capture() async {
    await WidgetsBinding.instance.endOfFrame;
    return _svc.captureAndStore(
      boundaryKey: _boundaryKey,
      fileId: widget.draft.id,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final receipt = await _capture();
      await _svc.saveToGallery(receipt, widget.draft.id);
      await _svc.syncMeta(widget.syncCollection, widget.draft.id, receipt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt gallery + local/cloud queue')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save fail: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final receipt = await _capture();
      await _svc.share(receipt, label: widget.draft.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share fail: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE8F5),
      appBar: kitschAppBar(context, title: 'Print receipt'),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetH = constraints.maxHeight * 0.75;
                final targetW = constraints.maxWidth - 12;
                return Center(
                  child: SizedBox(
                    height: targetH,
                    width: targetW,
                    child: Material(
                      elevation: 6,
                      shadowColor: Colors.black54,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: targetW,
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: ReceiptPaper(draft: widget.draft),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(
                        'Save',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: Text(
                        'Share',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.tertiary,
                        foregroundColor: scheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
