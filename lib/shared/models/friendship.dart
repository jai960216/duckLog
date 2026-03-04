import 'profile.dart';

class Friendship {
  final String id;
  final String requesterId;
  final String receiverId;
  final String status; // pending / accepted / rejected
  final DateTime createdAt;

  // Transient: from joins
  final Profile? requesterProfile;
  final Profile? receiverProfile;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.status = 'pending',
    required this.createdAt,
    this.requesterProfile,
    this.receiverProfile,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}
