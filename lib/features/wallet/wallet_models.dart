// Models for Wallet, Ledger, Credit Packages, Orders, and Checkout Gateway.

enum OrderStatus {
  pending,
  reconciling,
  paid,
  failed,
  expired,
  cancelled,
  unknown;

  static OrderStatus fromString(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'pending' => OrderStatus.pending,
      'reconciling' => OrderStatus.reconciling,
      'paid' => OrderStatus.paid,
      'failed' => OrderStatus.failed,
      'expired' => OrderStatus.expired,
      'cancelled' || 'canceled' => OrderStatus.cancelled,
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

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.provenance,
    required this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: _readInt(json, ['id', 'ledgerId']),
      delta: _readInt(json, ['delta', 'amount', 'credits']),
      reason: _readString(json, ['reason', 'type'], fallback: 'adjustment'),
      provenance: _readString(
        json,
        ['provenance', 'reference', 'referenceType', 'note', 'description'],
      ),
      createdAt: _readString(json, ['createdAt', 'timestamp']),
    );
  }

  final int id;
  final int delta;
  final String reason;
  final String provenance;
  final String createdAt;

  String get formattedDelta => delta >= 0 ? '+$delta' : '$delta';
}

class WalletOrder {
  const WalletOrder({
    required this.orderCode,
    required this.packageId,
    required this.packageName,
    required this.credits,
    required this.amountVnd,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.checkoutUrl,
    this.errorCode,
  });

  factory WalletOrder.fromJson(Map<String, dynamic> json) {
    return WalletOrder(
      orderCode: _readString(json, ['orderCode', 'code']),
      packageId: _readInt(json, ['packageId']),
      packageName: _readString(
        json,
        ['packageName', 'name'],
        fallback: 'Credit Package',
      ),
      credits: _readInt(json, ['credits', 'creditAmount']),
      amountVnd: _readInt(json, ['amountVnd', 'amount', 'priceVnd', 'price']),
      status: OrderStatus.fromString(_readNullableString(json, ['status'])),
      createdAt: _readString(json, ['createdAt']),
      expiresAt: _readNullableString(json, ['expiresAt']),
      checkoutUrl: _readNullableString(json, ['checkoutUrl', 'paymentUrl']),
      errorCode: _readNullableString(json, ['errorCode']),
    );
  }

  final String orderCode;
  final int packageId;
  final String packageName;
  final int credits;
  final int amountVnd;
  final OrderStatus status;
  final String createdAt;
  final String? expiresAt;
  final String? checkoutUrl;
  final String? errorCode;
}

class WalletSummary {
  const WalletSummary({
    required this.creditsPurchased,
    required this.creditsUsed,
    required this.balance,
    required this.ledger,
    required this.orders,
    this.explicitOpenOrder,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final purchased = _readInt(
      json,
      ['creditsPurchased', 'purchased', 'totalPurchased'],
    );
    final used = _readInt(json, ['creditsUsed', 'used', 'totalUsed']);
    final rawBalance = _readInt(
      json,
      ['balance', 'creditBalance'],
      fallback: purchased - used,
    );

    final ledgerList = (json['ledger'] ?? json['entries']) as List<dynamic>?;
    final ordersList = json['orders'] as List<dynamic>?;
    final openOrderJson = json['openOrder'] as Map<String, dynamic>?;

    return WalletSummary(
      creditsPurchased: purchased,
      creditsUsed: used,
      balance: rawBalance,
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
      explicitOpenOrder:
          openOrderJson == null ? null : WalletOrder.fromJson(openOrderJson),
    );
  }

  final int creditsPurchased;
  final int creditsUsed;
  final int balance;
  final List<LedgerEntry> ledger;
  final List<WalletOrder> orders;
  final WalletOrder? explicitOpenOrder;

  /// Derived balance from ledger totals (`creditsPurchased - creditsUsed`).
  int get derivedBalance => creditsPurchased - creditsUsed;

  /// Returns the single open order (`pending` or `reconciling`) if one exists.
  WalletOrder? get openOrder {
    if (explicitOpenOrder != null && explicitOpenOrder!.status.isOpen) {
      return explicitOpenOrder;
    }
    for (final order in orders) {
      if (order.status.isOpen) return order;
    }
    return null;
  }
}

class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceVnd,
    required this.isFeatured,
    required this.description,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: _readInt(json, ['id', 'packageId']),
      name: _readString(json, ['name', 'title'], fallback: 'Credit Package'),
      credits: _readInt(json, ['credits', 'creditAmount']),
      priceVnd: _readInt(json, ['priceVnd', 'price', 'amountVnd']),
      isFeatured: (json['isFeatured'] ?? json['featured']) == true,
      description: _readString(json, ['description', 'subtitle']),
    );
  }

  final int id;
  final String name;
  final int credits;
  final int priceVnd;
  final bool isFeatured;
  final String description;
}

class CheckoutPreview {
  const CheckoutPreview({
    required this.packageId,
    required this.packageName,
    required this.credits,
    required this.amountVnd,
    required this.hasOpenOrder,
    this.openOrderCode,
  });

  factory CheckoutPreview.fromJson(Map<String, dynamic> json) {
    return CheckoutPreview(
      packageId: _readInt(json, ['packageId', 'id']),
      packageName: _readString(
        json,
        ['packageName', 'name'],
        fallback: 'Credit Package',
      ),
      credits: _readInt(json, ['credits', 'creditAmount']),
      amountVnd: _readInt(json, ['amountVnd', 'priceVnd', 'amount']),
      hasOpenOrder: (json['hasOpenOrder'] ?? false) == true,
      openOrderCode: _readNullableString(json, ['openOrderCode']),
    );
  }

  final int packageId;
  final String packageName;
  final int credits;
  final int amountVnd;
  final bool hasOpenOrder;
  final String? openOrderCode;
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
