import 'package:dio/dio.dart';

import 'wallet_models.dart';

/// Repository for Wallet, Credit Packages, Checkout Orders, and Mock Gateway.
class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  Future<WalletSummary> getWallet() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/learner/wallet');
    return WalletSummary.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<CreditPackage>> getPackages() async {
    final response = await _dio.get<dynamic>('/api/packages');
    final data = response.data;
    final List<dynamic> list;
    if (data is List<dynamic>) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = (data['packages'] ?? data['items'] ?? const <dynamic>[])
          as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(CreditPackage.fromJson)
        .toList(growable: false);
  }

  Future<CheckoutPreview> previewCheckout(int packageId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/checkout/preview',
      queryParameters: {'packageId': packageId},
    );
    return CheckoutPreview.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<WalletOrder> createOrder(int packageId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/checkout/orders',
      data: {'packageId': packageId},
    );
    return WalletOrder.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<WalletOrder> getOrderResult(String orderCode) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/checkout/orders/$orderCode/result',
    );
    return WalletOrder.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<WalletOrder> handleReturn(String orderCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/checkout/return',
      data: {'orderCode': orderCode},
    );
    return WalletOrder.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> cancelOrder(String orderCode) async {
    await _dio.post<void>(
      '/api/checkout/cancel',
      data: {'orderCode': orderCode},
    );
  }

  Future<WalletOrder> mockGatewayAction({
    required String orderCode,
    required String action,
    String? errorCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/mock-gateway/action',
      data: {
        'orderCode': orderCode,
        'action': action,
        'errorCode': ?errorCode,
      },
    );
    return WalletOrder.fromJson(response.data ?? const <String, dynamic>{});
  }
}
