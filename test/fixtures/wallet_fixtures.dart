/// Wire payloads recorded from the running backend (learner@demo.local).
///
/// These are the assertion target for the wallet/checkout models: the key
/// names here are the backend's, not the app's. A rename on the backend must
/// fail a test rather than silently become a zero on screen.
library;

/// `GET /api/learner/wallet`.
///
/// `balance` (11) is deliberately not `creditsPurchased - creditsUsed`
/// (15 - 5 = 10): the difference is the `admin_grant` make-good.
const Map<String, dynamic> walletPayload = {
  'balance': 11,
  'creditsPurchased': 15,
  'creditsUsed': 5,
  'amountPurchased': 290000.00,
  'paidOrderCount': 2,
  'orders': [
    {
      'orderId': 1003,
      'orderCode': 'DH-20261113-0051',
      'paymentNo': 51,
      'packageId': 2,
      'packageName': 'Starter Pack',
      'credits': 5,
      'amount': 100000.00,
      'status': 'failed',
      'gateway': 'mock',
      'gatewayTxnRef': 'MOCK-51',
      'gatewayErrorCode': 'MOCK_DECLINED',
      'createdAt': '2026-11-13T10:46:20.5233943+00:00',
      'paidAt': null,
      'checkoutUrl': null,
    },
    {
      'orderId': 1,
      'orderCode': 'DH-20261014-0001',
      'paymentNo': 1,
      'packageId': 1,
      'packageName': 'Intensive Pack',
      'credits': 10,
      'amount': 190000.00,
      'status': 'paid',
      'gateway': 'mock',
      'gatewayTxnRef': 'plink-demo-10',
      'gatewayErrorCode': null,
      'createdAt': '2026-10-17T01:44:00.693929+07:00',
      'paidAt': '2026-10-17T01:44:00.693929+07:00',
      'checkoutUrl': null,
    },
  ],
  'ledger': [
    {
      'txnId': 1002,
      'reason': 'mock_exam_start',
      'delta': -1,
      'note': null,
      'createdAt': '2026-11-13T16:00:43.0753765+00:00',
      'orderCode': null,
    },
    {
      'txnId': 1001,
      'reason': 'mock_exam_start',
      'delta': -1,
      'note': null,
      'createdAt': '2026-11-13T15:43:21.9980661+00:00',
      'orderCode': null,
    },
    {
      'txnId': 5,
      'reason': 'mentor_booking',
      'delta': -1,
      'note': null,
      'createdAt': '2026-11-10T01:44:01.8712985+07:00',
      'orderCode': null,
    },
    {
      'txnId': 6,
      'reason': 'admin_grant',
      'delta': 1,
      'note': 'Complaint make-good: audio stream stutter refund',
      'createdAt': '2026-11-09T01:44:01.8868215+07:00',
      'orderCode': null,
    },
    {
      'txnId': 3,
      'reason': 'mock_exam_start',
      'delta': -1,
      'note': null,
      'createdAt': '2026-11-08T01:44:01.7988621+07:00',
      'orderCode': null,
    },
    {
      'txnId': 4,
      'reason': 'mentor_booking',
      'delta': -1,
      'note': null,
      'createdAt': '2026-11-06T01:44:01.8642311+07:00',
      'orderCode': null,
    },
    {
      'txnId': 2,
      'reason': 'purchase',
      'delta': 5,
      'note': null,
      'createdAt': '2026-10-24T01:44:00.724602+07:00',
      'orderCode': 'DH-20261014-0002',
    },
    {
      'txnId': 1,
      'reason': 'purchase',
      'delta': 10,
      'note': null,
      'createdAt': '2026-10-17T01:44:00.6954322+07:00',
      'orderCode': 'DH-20261014-0001',
    },
  ],
};

/// `GET /api/packages` (trimmed to the two packages the tests buy).
const List<Map<String, dynamic>> packagesPayload = [
  {
    'packageId': 2,
    'name': 'Starter Pack',
    'credits': 5,
    'price': 100000.00,
    'isActive': true,
    'isFeatured': false,
    'features': '5 full-exam / grading credits\nNever expires',
    'displayOrder': 1,
    'ordersSold': 0,
    'totalRevenue': 0,
  },
  {
    'packageId': 1,
    'name': 'Intensive Pack',
    'credits': 10,
    'price': 190000.00,
    'isActive': true,
    'isFeatured': true,
    'features': '10 full-exam / grading credits\nNever expires',
    'displayOrder': 2,
    'ordersSold': 0,
    'totalRevenue': 0,
  },
];

/// `GET /api/checkout/preview?packageId=2` with no order open.
const Map<String, dynamic> checkoutPreviewPayload = {
  'packageId': 2,
  'packageName': 'Starter Pack',
  'credits': 5,
  'price': 100000.00,
  'currentBalance': 11,
  'balanceAfter': 16,
  'openOrder': null,
};

/// `GET /api/checkout/preview?packageId=1` while an order is open.
const Map<String, dynamic> checkoutPreviewOpenOrderPayload = {
  'packageId': 1,
  'packageName': 'Intensive Pack',
  'credits': 10,
  'price': 190000.00,
  'currentBalance': 0,
  'balanceAfter': 10,
  'openOrder': {
    'orderId': 2003,
    'orderCode': 'DH-20261113-0101',
    'paymentNo': 101,
    'packageId': 1,
    'packageName': 'Intensive Pack',
    'credits': 10,
    'amount': 190000.00,
    'status': 'pending',
    'gateway': 'mock',
    'gatewayTxnRef': 'MOCK-101',
    'gatewayErrorCode': null,
    'createdAt': '2026-11-13T16:48:04.3859891+00:00',
    'paidAt': null,
    'checkoutUrl': null,
  },
};

/// `POST /api/checkout/orders` — no package name, credits or id in this DTO,
/// and the mock gateway's `checkoutUrl` is root-relative.
const Map<String, dynamic> createdOrderPayload = {
  'orderId': 2003,
  'orderCode': 'DH-20261113-0101',
  'paymentNo': 101,
  'amount': 190000.00,
  'gateway': 'mock',
  'checkoutUrl': '/checkout/mock-gateway?orderCode=DH-20261113-0101',
  'status': 'pending',
};

/// `GET /api/checkout/orders/{code}/result` — note `gatewayErrorCode`, and the
/// checkout url is absent here even for a pending order.
Map<String, dynamic> paymentResultPayload({
  String status = 'pending',
  String? gatewayErrorCode,
}) {
  return {
    'orderId': 2003,
    'orderCode': 'DH-20261113-0101',
    'status': status,
    'packageName': 'Intensive Pack',
    'credits': 10,
    'amount': 190000.00,
    'gateway': 'mock',
    'createdAt': '2026-11-13T16:48:04.3859891+00:00',
    'paidAt': null,
    'currentBalance': 0,
    'gatewayErrorCode': gatewayErrorCode,
    'message': null,
    'checkoutUrl': null,
    'packageId': 1,
  };
}
