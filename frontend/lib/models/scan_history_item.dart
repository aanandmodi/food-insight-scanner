/// Typed model for scan history entries stored in Firestore.
class ScanHistoryItem {
  final String scanId;
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final Map<String, dynamic> nutrition;
  final List<String> allergens;
  final DateTime scannedAt;

  const ScanHistoryItem({
    required this.scanId,
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.nutrition,
    required this.allergens,
    required this.scannedAt,
  });

  factory ScanHistoryItem.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final raw = map['scannedAt'];
    if (raw is String) {
      parsedDate = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      // Firestore Timestamp — access via .toDate() at the call site
      parsedDate = DateTime.now();
    }

    return ScanHistoryItem(
      scanId: map['scanId'] as String? ?? map['id'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      brand: map['brand'] as String?,
      imageUrl: map['image'] as String?,
      nutrition: Map<String, dynamic>.from(map['nutrition'] as Map? ?? {}),
      allergens: List<String>.from(map['allergens'] as List? ?? []),
      scannedAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scanId': scanId,
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'image': imageUrl,
      'nutrition': nutrition,
      'allergens': allergens,
      'scannedAt': scannedAt.toIso8601String(),
    };
  }
}
