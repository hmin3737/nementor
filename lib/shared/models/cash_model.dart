import 'package:equatable/equatable.dart';

enum LedgerType {
  iapCharge,
  questionHold,
  questionRefund,
  mentorEarn,
  platformFee,
  consultingHold,
  adminAdjust,
}

class CashLedgerEntry extends Equatable {
  const CashLedgerEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.balance,
    required this.type,
    this.refId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int amount; // 양수: 적립, 음수: 차감
  final int balance; // 변동 후 잔액
  final LedgerType type;
  final String? refId;
  final String? note;
  final DateTime createdAt;

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) =>
      CashLedgerEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        amount: json['amount'] as int,
        balance: json['balance'] as int,
        type: LedgerType.values.firstWhere(
          (t) => t.name == _snakeToCamel(json['type'] as String),
          orElse: () => LedgerType.adminAdjust,
        ),
        refId: json['ref_id'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static String _snakeToCamel(String s) {
    return s.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m[1]!.toUpperCase(),
    );
  }

  String get typeLabel {
    switch (type) {
      case LedgerType.iapCharge:
        return '캐시 충전';
      case LedgerType.questionHold:
        return '질문 등록';
      case LedgerType.questionRefund:
        return '질문 취소 환불';
      case LedgerType.mentorEarn:
        return '답변 수익';
      case LedgerType.platformFee:
        return '플랫폼 수수료';
      case LedgerType.consultingHold:
        return '학습상담';
      case LedgerType.adminAdjust:
        return '관리자 조정';
    }
  }

  @override
  List<Object?> get props => [id, userId, amount, type, createdAt];
}

class IapProduct {
  const IapProduct({
    required this.productId,
    required this.cashAmount,
    required this.price,
    required this.priceLabel,
  });

  final String productId;
  final int cashAmount;
  final int price;
  final String priceLabel;

  // 앱스토어 커넥트에 등록된 상품 ID 목록
  static const List<IapProduct> products = [
    IapProduct(
      productId: 'nementor.cash.5000',
      cashAmount: 5000,
      price: 5000,
      priceLabel: '₩5,000',
    ),
    IapProduct(
      productId: 'nementor.cash.10000',
      cashAmount: 10000,
      price: 10000,
      priceLabel: '₩10,000',
    ),
    IapProduct(
      productId: 'nementor.cash.30000',
      cashAmount: 30000,
      price: 30000,
      priceLabel: '₩30,000',
    ),
    IapProduct(
      productId: 'nementor.cash.50000',
      cashAmount: 50000,
      price: 50000,
      priceLabel: '₩50,000',
    ),
  ];
}
