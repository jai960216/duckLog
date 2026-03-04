class Receipt {
  final String id;
  final String userId;
  final String photoUrl;
  final Map<String, dynamic>? extractedData;
  final int? totalAmount;
  final String? storeName;
  final DateTime? purchasedAt;
  final bool isProcessed;
  final DateTime createdAt;

  const Receipt({
    required this.id,
    required this.userId,
    required this.photoUrl,
    this.extractedData,
    this.totalAmount,
    this.storeName,
    this.purchasedAt,
    this.isProcessed = false,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      photoUrl: json['photo_url'] as String,
      extractedData: json['extracted_data'] as Map<String, dynamic>?,
      totalAmount: json['total_amount'] as int?,
      storeName: json['store_name'] as String?,
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
      isProcessed: json['is_processed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'photo_url': photoUrl,
      'extracted_data': extractedData,
      'total_amount': totalAmount,
      'store_name': storeName,
      'purchased_at': purchasedAt?.toIso8601String().split('T').first,
      'is_processed': isProcessed,
    };
  }

  List<ReceiptItem> get items {
    if (extractedData == null || extractedData!['items'] == null) return [];
    return (extractedData!['items'] as List)
        .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ReceiptItem {
  final String name;
  final int? price;
  final int? quantity;

  const ReceiptItem({
    required this.name,
    this.price,
    this.quantity,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String,
      price: json['price'] as int?,
      quantity: json['quantity'] as int?,
    );
  }
}
