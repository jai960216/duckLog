class Subscription {
  final String id;
  final String userId;
  final String plan;
  final String status;
  final String? provider;
  final String? providerSubscriptionId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    this.provider,
    this.providerSubscriptionId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPro =>
      (plan == 'pro' || plan == 'pro_monthly' || plan == 'pro_yearly') &&
      status == 'active' &&
      (currentPeriodEnd == null || currentPeriodEnd!.isAfter(DateTime.now()));

  String get planDisplayName {
    switch (plan) {
      case 'pro':
        return 'Pro';
      case 'pro_monthly':
        return 'Pro 월간';
      case 'pro_yearly':
        return 'Pro 연간';
      default:
        return 'Free';
    }
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      provider: json['provider'] as String?,
      providerSubscriptionId: json['provider_subscription_id'] as String?,
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.parse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory Subscription.free(String userId) {
    return Subscription(
      id: '',
      userId: userId,
      plan: 'free',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
