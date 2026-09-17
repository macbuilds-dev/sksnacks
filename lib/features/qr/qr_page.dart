import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../brand/kitsch_widgets.dart';
import '../../brand/kitsch_qr_fab.dart';
import '../../brand/qr_sheet.dart';
import '../../brand/ui_helpers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/repo_providers.dart';
import '../../l10n/app_copy.dart';

class QrPage extends ConsumerStatefulWidget {
  const QrPage({super.key});

  @override
  ConsumerState<QrPage> createState() => _QrPageState();
}

class _ScannedHit {
  const _ScannedHit.item(this.item)
      : party = null,
        bill = null;
  const _ScannedHit.party(this.party)
      : item = null,
        bill = null;
  const _ScannedHit.bill(this.bill)
      : item = null,
        party = null;

  final Item? item;
  final Party? party;
  final Bill? bill;
}

class _QrPageState extends ConsumerState<QrPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  _ScannedHit? _hit;
  String? _lastRaw;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _onDetect(String raw) async {
    final now = DateTime.now();
    if (raw == _lastRaw &&
        now.difference(_lastAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastRaw = raw;
    _lastAt = now;

    final inv = ref.read(inventoryRepoProvider);
    final khata = ref.read(khataRepoProvider);

    final item = await inv.resolveItemQr(raw);
    if (item != null) {
      if (!mounted) return;
      setState(() => _hit = _ScannedHit.item(item));
      return;
    }
    final party = await khata.resolvePartyQr(raw);
    if (party != null) {
      if (!mounted) return;
      setState(() => _hit = _ScannedHit.party(party));
      return;
    }
    final bill = await khata.resolveBillQr(raw);
    if (!mounted) return;
    if (bill != null) {
      setState(() => _hit = _ScannedHit.bill(bill));
    } else {
      setState(() => _hit = null);
      showNeed(context, Copy.qrNoMatch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kitschAppBar(
        context,
        title: Copy.qrTitle,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: Copy.qrScan),
            Tab(text: Copy.qrMake),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ScanTab(hit: _hit, onDetect: _onDetect),
          const _MakeTab(),
        ],
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({required this.hit, required this.onDetect});
  final _ScannedHit? hit;
  final Future<void> Function(String id) onDetect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                onDetect(raw);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: KitschSticker(
            child: hit == null
                ? const Text(Copy.qrHint)
                : hit!.item != null
                    ? _ItemResult(item: hit!.item!)
                    : hit!.party != null
                        ? _PartyResult(party: hit!.party!)
                        : _BillResult(bill: hit!.bill!),
          ),
        ),
      ],
    );
  }
}

class _ItemResult extends StatelessWidget {
  const _ItemResult({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.qrOfItem, style: Theme.of(context).textTheme.labelLarge),
        Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          '${Copy.qrCode} ${item.qrCode} · Rs ${item.salePrice.toStringAsFixed(0)} · ${item.unit}',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showEntityQr(
              context,
              title: Copy.qrOfItem,
              qrCode: item.qrCode,
              detailLines: [item.name],
            ),
            icon: const KitschQrIcon(),
            label: const Text(Copy.showQr),
          ),
        ),
      ],
    );
  }
}

class _PartyResult extends StatelessWidget {
  const _PartyResult({required this.party});
  final Party party;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.qrOfParty, style: Theme.of(context).textTheme.labelLarge),
        Text(party.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          '${party.qrCode} · Baqaya Rs ${party.balance.toStringAsFixed(0)}',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showEntityQr(
              context,
              title: Copy.qrOfParty,
              qrCode: party.qrCode,
              detailLines: [party.name],
            ),
            icon: const KitschQrIcon(),
            label: const Text(Copy.showQr),
          ),
        ),
      ],
    );
  }
}

class _BillResult extends StatelessWidget {
  const _BillResult({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.qrOfBill, style: Theme.of(context).textTheme.labelLarge),
        Text(
          bill.billNo ?? bill.id,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${bill.qrCode} · Rs ${bill.total.toStringAsFixed(0)} · ${bill.status}',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showEntityQr(
              context,
              title: Copy.qrOfBill,
              qrCode: bill.qrCode,
              detailLines: [bill.billNo ?? bill.id],
            ),
            icon: const KitschQrIcon(),
            label: const Text(Copy.showQr),
          ),
        ),
      ],
    );
  }
}

class _MakeTab extends ConsumerWidget {
  const _MakeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Item>>(
      stream: ref.watch(inventoryRepoProvider).watchItems(),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('Pehle saman banao, phir QR.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: KitschSticker(
                onTap: () => showEntityQr(
                  context,
                  title: Copy.qrOfItem,
                  qrCode: item.qrCode,
                  detailLines: [
                    item.name,
                    '${Copy.price}: Rs ${item.salePrice.toStringAsFixed(0)}',
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    QrImageView(data: item.qrCode, size: 160),
                    Text(item.qrCode,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      Copy.qrMakeHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
