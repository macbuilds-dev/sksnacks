/// Catalog options for product forms (English labels).
class CatalogOptions {
  CatalogOptions._();

  static const categories = <String>[
    'Raw material',
    'Finished goods',
    'Namkeen',
    'Sweets',
    'Packaging',
    'Other',
  ];

  static const units = <String>[
    'pcs',
    'kg',
    'ton',
    'bori',
    'pack',
    'box',
    'dozen',
    'litre',
    'bag',
  ];

  /// Common low-stock reminder thresholds (owner picks one or types custom).
  static const reorderPresets = <double>[5, 10, 20, 50, 100];

  static const moveTypes = <({String value, String label, String hint})>[
    (
      value: 'purchase',
      label: 'Buy in',
      hint: 'Stock arrived from a supplier',
    ),
    (
      value: 'sale',
      label: 'Sell out',
      hint: 'Stock left for a customer sale',
    ),
    (
      value: 'transfer',
      label: 'Transfer',
      hint: 'Move stock from one place to another',
    ),
    (
      value: 'waste',
      label: 'Waste',
      hint: 'Damaged or thrown away',
    ),
    (
      value: 'adjust_in',
      label: 'Adjust up',
      hint: 'Correction: add missing count',
    ),
    (
      value: 'adjust_out',
      label: 'Adjust down',
      hint: 'Correction: remove extra count',
    ),
    (
      value: 'return',
      label: 'Return in',
      hint: 'Goods came back into stock',
    ),
  ];
}
