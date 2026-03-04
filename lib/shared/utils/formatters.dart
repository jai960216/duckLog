import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  // 금액 포맷: 1,234,567원
  static String price(int? amount) {
    if (amount == null) return '-';
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)}원';
  }

  // 짧은 금액: 1.2만원, 123만원
  static String priceShort(int amount) {
    if (amount >= 10000) {
      final man = amount / 10000;
      if (man == man.roundToDouble()) {
        return '${man.round()}만원';
      }
      return '${man.toStringAsFixed(1)}만원';
    }
    return price(amount);
  }

  // 날짜: 2026.03.04
  static String date(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy.MM.dd').format(date);
  }

  // 짧은 날짜: 3/4
  static String dateShort(DateTime date) {
    return DateFormat('M/d').format(date);
  }

  // 월: 2026년 3월
  static String yearMonth(DateTime date) {
    return DateFormat('yyyy년 M월').format(date);
  }

  // 상대 시간: 방금 전, 5분 전, 2시간 전, 3일 전
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}개월 전';
    return '${(diff.inDays / 365).floor()}년 전';
  }

  // 요일: 월, 화, 수...
  static String weekday(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday - 1];
  }
}
