import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

// colors (same as the Sales / Expenses screens)
class _T {
  static const card = Color(0xFF141B28);
  static const border = Color(0xFF1E2A3E);
  static const accent = Color(0xFF6C63FF);
  static const red = Color(0xFFEF4444);
  static const textPri = Color(0xFFF1F5F9);
  static const textSec = Color(0xFF94A3B8);
}

// ─── Receipt (scanned PDF) viewer ──────────────────────────────────
// 1. checks the file on the server first, so a real reason is shown (not found, S3 error…)
// 2. shows it through Google's PDF viewer (Android WebView can't open PDFs by itself)
// 3. Google's viewer sometimes comes back blank → retried automatically, plus a reload button
class ReceiptViewerDialog extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const ReceiptViewerDialog({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<ReceiptViewerDialog> createState() => _ReceiptViewerDialogState();
}

class _ReceiptViewerDialogState extends State<ReceiptViewerDialog> {
  WebViewController? _web;
  bool _loading = true;
  String _error = '';
  int _tries = 0;

  String get _viewerUrl =>
      'https://docs.google.com/viewer?embedded=true&url=${Uri.encodeComponent(widget.pdfUrl)}';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = '';
      _tries = 0;
    });
    try {
      final res = await http
          .get(Uri.parse(widget.pdfUrl))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode != 200) {
        final msg = res.body.length < 200 ? res.body : '';
        setState(() {
          _loading = false;
          _error = res.statusCode == 404
              ? 'The file was not found.'
              : 'Could not load the file (${res.statusCode}). $msg';
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server.\n$e';
      });
      return;
    }

    _web ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _checkBlank(),
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _error = 'Could not show the file. ${e.description}';
              });
            }
          },
        ),
      );
    _web!.loadRequest(Uri.parse(_viewerUrl));
  }

  // Google's viewer returns an empty page now and then → try again (max 3 times)
  Future<void> _checkBlank() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || _web == null) return;
    var blank = false;
    try {
      final len = await _web!.runJavaScriptReturningResult(
        'document.body ? document.body.innerHTML.length : 0',
      );
      blank = (int.tryParse(len.toString()) ?? 0) < 50;
    } catch (_) {}
    if (blank && _tries < 3) {
      _tries++;
      _web!.loadRequest(Uri.parse(_viewerUrl));
      return;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        if (blank) _error = 'The viewer did not load. Tap reload to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: _T.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _T.textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _T.textSec,
                      size: 20,
                    ),
                    onPressed: _loading ? null : _start,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _T.textSec,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: _T.border, height: 1),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    if (_web != null && _error.isEmpty)
                      WebViewWidget(controller: _web!),
                    if (_error.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: _T.red,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _T.textSec,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                onPressed: _start,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_loading)
                      Container(
                        color: _T.card,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: _T.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
