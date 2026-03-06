import 'goods.dart';

class Receipt {
  final String id;
  final String userId;
  final String photoUrl;
  final Map<String, dynamic>? extractedData;
  final int? totalAmount;
  final String? storeName;
  final DateTime? purchasedAt;
  final bool isProcessed;
  final String? category;
  final String? purchaseChannel;
  final String? expenseType;
  final String? memo;
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
    this.category,
    this.purchaseChannel,
    this.expenseType,
    this.memo,
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
      category: json['category'] as String?,
      purchaseChannel: json['purchase_channel'] as String?,
      expenseType: json['expense_type'] as String?,
      memo: json['memo'] as String?,
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
      'category': category,
      'purchase_channel': purchaseChannel,
      'expense_type': expenseType,
      'memo': memo,
    };
  }

  List<ReceiptItem> get items {
    if (extractedData == null || extractedData!['items'] == null) return [];
    return (extractedData!['items'] as List)
        .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 굿즈 카테고리 라벨은 Goods.categoryLabel() 재사용
  String? get categoryLabel =>
      category != null ? Goods.categoryLabel(category!) : null;

  static const List<String> purchaseChannels = [
    'online',
    'offline',
    'event',
    'secondhand',
    'overseas',
    'other',
  ];

  static String purchaseChannelLabel(String channel) {
    switch (channel) {
      case 'online':
        return '온라인';
      case 'offline':
        return '오프라인';
      case 'event':
        return '이벤트/행사';
      case 'secondhand':
        return '중고거래';
      case 'overseas':
        return '해외구매';
      case 'other':
        return '기타';
      default:
        return channel;
    }
  }

  static const List<String> expenseTypes = [
    'goods',
    'ticket',
    'album',
    'food',
    'transport',
    'other',
  ];

  static String expenseTypeLabel(String type) {
    switch (type) {
      case 'goods':
        return '굿즈';
      case 'ticket':
        return '티켓/입장';
      case 'album':
        return '음반/앨범';
      case 'food':
        return '식비';
      case 'transport':
        return '교통/숙박';
      case 'other':
        return '기타';
      default:
        return type;
    }
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
