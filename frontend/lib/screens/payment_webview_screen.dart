import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';
import 'package:sartaroshxona/services/api_service.dart';

/// To'lov tizimi (Payme/Click) checkout sahifasini WebView'da ochadi va
/// to'lov holatini fonда polling qilib turadi. To'langach avtomatik yopiladi
/// va `true` qaytaradi. Foydalanuvchi yopsa `false` qaytaradi.
class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final int appointmentId;
  final String gatewayName;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.appointmentId,
    required this.gatewayName,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _loading = true;
  bool _checking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          // To'lovdan keyin qaytish sahifasiga o'tsa — darhol tekshiramiz
          if (url.contains('/payment/return')) {
            _check();
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    // Fonda har 3 soniyada to'lov holatini tekshirib turish
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _done) return;
    _checking = true;
    final paid = await ApiService().isPaymentPaid(widget.appointmentId);
    _checking = false;
    if (paid && mounted && !_done) {
      _done = true;
      _pollTimer?.cancel();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text("${widget.gatewayName} to'lov", style: TextStyle(color: colors.textPrimary, fontSize: 16)),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          // To'lovni qo'lda tekshirish
          _checking
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colors.primary),
                  tooltip: "To'lovni tekshirish",
                  onPressed: _check,
                ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Container(
              color: colors.background,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
