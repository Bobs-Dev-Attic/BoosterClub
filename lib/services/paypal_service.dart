import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_config.dart';

/// Result of asking the backend to create a PayPal order for a pending
/// donation. [approveUrl] is the PayPal-hosted page the donor is sent to.
class PayPalOrder {
  final String orderId;
  final String approveUrl;
  const PayPalOrder({required this.orderId, required this.approveUrl});
}

/// Thin client over the PayPal-backed Cloud Functions.
///
/// The heavy lifting (talking to PayPal with the secret, capturing payments,
/// verifying webhooks) happens server-side; this class only invokes the
/// callables and, in demo mode, simulates their effects so the Donate page is
/// fully previewable without a live PayPal account.
class PayPalService {
  PayPalService({FirebaseFunctions? functions})
      : _functions = functions ??
            (AppConfig.paypalConfigured ? FirebaseFunctions.instance : null);

  final FirebaseFunctions? _functions;

  bool get isLive => AppConfig.paypalConfigured;

  /// Asks the backend to create a PayPal order for [donationId] (a pending
  /// donation the app has already written to Firestore). Returns the order id
  /// and the approval URL to open for the donor.
  Future<PayPalOrder> createOrder(String donationId) async {
    final callable = _functions!.httpsCallable('createPayPalOrder');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'donationId': donationId,
    });
    final data = res.data;
    return PayPalOrder(
      orderId: (data['orderId'] ?? '').toString(),
      approveUrl: (data['approveUrl'] ?? '').toString(),
    );
  }

  /// Captures an approved order (belt-and-suspenders alongside the webhook).
  /// Safe to call more than once — the server is idempotent. Returns true if
  /// the payment is confirmed completed.
  Future<bool> captureOrder(String donationId) async {
    final callable = _functions!.httpsCallable('capturePayPalOrder');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'donationId': donationId,
    });
    return res.data['status'] == 'completed';
  }
}
