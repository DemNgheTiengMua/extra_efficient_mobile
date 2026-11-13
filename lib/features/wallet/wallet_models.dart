// Models for Wallet, Ledger, Credit Packages, Orders, and Checkout Gateway.
//
// Field names are the backend's own, verified against the running API:
// `WalletDto`, `CreditLedgerEntryDto`, `OrderDto`, `PaymentResultDto`,
// `PackageDto`, `CheckoutPreviewDto`, `CreateOrderResponse`.

enum OrderStatus {
  pending,
  reconciling,
  paid,
  failed,
  expired,
  unknown;

  static OrderStatus fromString(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'pending' => OrderStatus.pending,
      'reconciling' => OrderStatus.reconciling,
      'paid' => OrderStatus.paid,
      'failed' => OrderStatus.failed,
      'expired' => OrderStatus.expired,
      _ => OrderStatus.unknown,
    };
  }

  bool get isOpen =>
      this == OrderStatus.pending || this == OrderStatus.reconciling;

  String get label => name.toUpperCase();
}

int _readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
  }
  return null;
}

/// One row of the append-only credit ledger (`CreditLedgerEntryDto`).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.note,
    required this.createdAt,
    this.orderCode,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: _readInt(json, ['txnId']),
      delta: _readInt(json, ['delta']),
      reason: _readString(json, ['reason'], fallback: 'adjustment'),
      note: _readString(json, ['note']),
      createdAt: _readString(json, ['createdAt']),
      orderCode: _readNullableString(json, ['orderCode']),
    );
  }

  final int id;
  final int delta;
  final String reason;
  final String note;
  final String createdAt;
  final String? orderCode;

  String get formattedDelta => delta >= 0 ? '+$delta' : '$delta';
}

/// A credit package order (`OrderDto` / `PaymentResultDto` /
/// `CreateOrderResponse`).
class WalletOrder {
  const WalletOrder({
    required this.orderCode,
    required this.packageId,
    required this.packageName,
    required this.credits,
    required this.amountVnd,
    required this.status,
    required this.createdAt,
    this.checkoutUrl,
    this.errorCode,
  });

  factory WalletOrder.fromJson(Map<String, dynamic> json) {
    return WalletOrder(
      orderCode: _readString(json, ['orderCode']),
      packageId: _readInt(json, ['packageId']),
      packageName: _readString(json, ['packageName']),
      credits: _readInt(json, ['credits']),
      amountVnd: _readInt(json, ['amount']),
      status: OrderStatus.fromString(_readNullableString(json, ['status'])),
      createdAt: _readString(json, ['createdAt']),
      checkoutUrl: _readNullableString(json, ['checkoutUrl']),
      errorCode: _readNullableString(json, ['gatewayErrorCode']),
    );
  }

  final String orderCode;
  final int packageId;
  final String packageName;
  final int credits;
  final int amountVnd;
  final OrderStatus status;
  final String createdAt;
  final String? checkoutUrl;
  final String? errorCode;

  /// Fills the package facts `CreateOrderResponse` omits, without overwriting
  /// values the backend already sent.
  WalletOrder withPackage({
    int? packageId,
    String? packageName,
    int? credits,
  }) {
    return WalletOrder(
      orderCode: orderCode,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      credits: credits ?? this.credits,
      amountVnd: amountVnd,
      status: status,
      createdAt: createdAt,
      checkoutUrl: checkoutUrl,
      errorCode: errorCode,
    );
  }

  WalletOrder copyWith({OrderStatus? status, String? errorCode}) {
    return WalletOrder(
      orderCode: orderCode,
      packageId: packageId,
      packageName: packageName,
      credits: credits,
      amountVnd: amountVnd,
      status: status ?? this.status,
      createdAt: createdAt,
      checkoutUrl: checkoutUrl,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

/// The learner's wallet (`WalletDto`).
class WalletSummary {
  const WalletSummary({
    required this.creditsPurchased,
    required this.creditsUsed,
    required this.balance,
    required this.ledger,
    required this.orders,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final ledgerList = json['ledger'] as List<dynamic>?;
    final ordersList = json['orders'] as List<dynamic>?;

    return WalletSummary(
      creditsPurchased: _readInt(json, ['creditsPurchased']),
      creditsUsed: _readInt(json, ['creditsUsed']),
      // The ledger balance is authoritative: it includes admin grants, which
      // purchased-minus-used cannot express.
      balance: _readInt(json, ['balance']),
      ledger: ledgerList == null
          ? const []
          : ledgerList
              .whereType<Map<String, dynamic>>()
              .map(LedgerEntry.fromJson)
              .toList(growable: false),
      orders: ordersList == null
          ? const []
          : ordersList
              .whereType<Map<String, dynamic>>()
              .map(WalletOrder.fromJson)
              .toList(growable: false),
    );
  }

  final int creditsPurchased;
  final int creditsUsed;
  final int balance;
  final List<LedgerEntry> ledger;
  final List<WalletOrder> orders;

  /// Returns the single open order (`pending` or `reconciling`) if one exists.
  WalletOrder? get openOrder {
    for (final order in orders) {
      if (order.status.isOpen) return order;
    }
    return null;
  }
}

/// A purchasable credit package (`PackageDto`).
class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceVnd,
    required this.isFeatured,
    required this.features,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: _readInt(json, ['packageId']),
      name: _readString(json, ['name']),
      credits: _readInt(json, ['credits']),
      priceVnd: _readInt(json, ['price']),
      isFeatured: json['isFeatured'] == true,
      features: _readString(json, ['features']),
    );
  }

  final int id;
  final String name;
  final int credits;
  final int priceVnd;
  final bool isFeatured;

  /// Newline-separated feature list from the backend.
  final String features;

  List<String> get featureList => features
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

/// The pre-order quote (`CheckoutPreviewDto`).
class CheckoutPreview {
  const CheckoutPreview({
    required this.packageId,
    required this.packageName,
    required this.credits,
    required this.amountVnd,
    this.openOrder,
  });

  factory CheckoutPreview.fromJson(Map<String, dynamic> json) {
    final openOrderJson = json['openOrder'] as Map<String, dynamic>?;
    return CheckoutPreview(
      packageId: _readInt(json, ['packageId']),
      packageName: _readString(json, ['packageName']),
      credits: _readInt(json, ['credits']),
      amountVnd: _readInt(json, ['price']),
      openOrder:
          openOrderJson == null ? null : WalletOrder.fromJson(openOrderJson),
    );
  }

  final int packageId;
  final String packageName;
  final int credits;
  final int amountVnd;

  /// The learner's already-open order, which blocks a second order.
  final WalletOrder? openOrder;
}

/// Formats Vietnamese Dong amounts with thousands separators in monospace-friendly form.
String formatVnd(int amount) {
  final raw = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(raw[i]);
  }
  return '${buf.toString()} ₫';
}
