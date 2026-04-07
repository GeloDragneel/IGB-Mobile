import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';
import 'sales_scan_dialog.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../widgets/chat_bubble.dart';

// ─── Theme Constants ───────────────────────────────────────────────
class _T {
  static const bg = Color(0xFF080C14);
  static const surface = Color(0xFF0F1521);
  static const card = Color(0xFF141B28);
  static const cardHover = Color(0xFF1A2235);
  static const border = Color(0xFF1E2A3E);
  static const accent = Color(0xFF6C63FF);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const textPri = Color(0xFFF1F5F9);
  static const textSec = Color(0xFF94A3B8);
  static const textMut = Color(0xFF475569);
}

// ─── Model ─────────────────────────────────────────────────────────
class SalesRecord {
  final String fileName;
  final String status;
  final String dateAdded;
  final String reference;
  final int id;

  SalesRecord({
    required this.fileName,
    required this.status,
    required this.dateAdded,
    required this.reference,
    required this.id,
  });

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    return SalesRecord(
      fileName: json['Filename'] ?? '',
      status: json['Status'] ?? '',
      dateAdded: json['DateAdded'] ?? '',
      reference: json['Reference'] ?? '',
      id: json['ID'] is int
          ? json['ID']
          : int.tryParse(json['ID'].toString()) ?? 0,
    );
  }
}

// ─── Sales Screen ──────────────────────────────────────────────────
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  final formatter = NumberFormat('#,##0.00');
  final _searchCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  Future<List<SalesRecord>> _futureRecords = Future.value([]);
  List<SalesRecord> _allRecords = [];
  List<SalesRecord> _filteredRecords = [];
  int _currentPage = 1;
  static const _perPage = 10;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _futureRecords = _fetchRecords();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<SalesRecord>> _fetchRecords() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await http.get(
      Uri.parse(
        'https://igb-fems.com/LIVE/mobile_php/sales.php'
        '?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}',
      ),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['result'] == 'Success') {
        final records = (data['invoices'] as List)
            .map((e) => SalesRecord.fromJson(e))
            .toList();
        if (mounted) {
          setState(() {
            _allRecords = records;
            _filteredRecords = records;
            _currentPage = 1;
          });
          _animCtrl.forward(from: 0);
        }
        return records;
      }
    }
    return [];
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredRecords = _allRecords.where((r) {
        final matchSearch = q.isEmpty || r.fileName.toLowerCase().contains(q);
        final matchStatus = _statusFilter == 'All' || r.status == _statusFilter;
        return matchSearch && matchStatus;
      }).toList();
      _currentPage = 1;
    });
  }

  int get _totalPages =>
      (_filteredRecords.length / _perPage).ceil().clamp(1, 999);

  List<SalesRecord> get _pageRecords {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _filteredRecords.length);
    return _filteredRecords.sublist(start, end);
  }

  Future<void> _deleteRecord(SalesRecord record) async {
    final loc = AppLocalizations.of(context);
    try {
      final res = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/delete_transaction.php?id=${record.id}',
        ),
      );
      if (res.statusCode == 200) {
        _showSnack(loc.recordDeletedSuccess, _T.green);
        final records = await _fetchRecords();
        if (!mounted) return;
        setState(() {
          _allRecords = records;
          _filteredRecords = records;
        });
      } else {
        _showSnack(loc.failedToDeleteRecord, _T.red);
      }
    } catch (e) {
      _showSnack('Error: $e', _T.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _timeAgo(String dateStr) {
    try {
      final d = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final date = DateTime(d.year, d.month, d.day);
      final diff = today.difference(date).inDays;
      if (diff == 0) return AppLocalizations.of(context).today;
      if (diff == 1) return AppLocalizations.of(context).yesterday;
      if (diff < 7) return '$diff ${AppLocalizations.of(context).daysAgo}';
      if (diff < 30) {
        return '${(diff / 7).floor()} ${AppLocalizations.of(context).weeksAgo}';
      }
      return AppLocalizations.of(context).formatDate(d);
    } catch (e) {
      final d = DateTime.tryParse(dateStr);
      if (d != null) return AppLocalizations.of(context).formatDate(d);
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      drawer: AppDrawer(selectedIndex: 3),
      body: FutureBuilder<List<SalesRecord>>(
        future: _futureRecords,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _T.accent),
            );
          }
          if (snap.hasError) {
            return _buildError(snap.error.toString());
          }
          return Stack(
            // 👈 Wrap with Stack
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    _buildSearchAndFilter(),
                    Expanded(child: _buildList()),
                    if (_totalPages > 1) _buildPagination(),
                  ],
                ),
              ),
              const ChatBubble(),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _T.surface,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _T.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _T.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context).sales,
            style: TextStyle(
              color: _T.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => SalesScanDialog(
                onUploadSuccess: () async {
                  final records = await _fetchRecords();
                  if (!mounted) return;
                  setState(() {
                    _allRecords = records;
                    _filteredRecords = records;
                  });
                },
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: Text(
              AppLocalizations.of(context).scan,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final total = _allRecords.length;
    final pending = _allRecords.where((r) => r.status == 'Pending').length;
    final confirmed = _allRecords.where((r) => r.status == 'Confirmed').length;
    final invalid = _allRecords.where((r) => r.status == 'Invalid').length;
    final partiallyInvalid = _allRecords
        .where((r) => r.status == 'Partially Invalid')
        .length;

    final filters = [
      {
        'label': AppLocalizations.of(context).all,
        'value': 'All',
        'count': total,
        'color': _T.accent,
      },
      {
        'label': AppLocalizations.of(context).pending,
        'value': 'Pending',
        'count': pending,
        'color': _T.amber,
      },
      {
        'label': AppLocalizations.of(context).confirmed,
        'value': 'Confirmed',
        'count': confirmed,
        'color': _T.green,
      },
      {
        'label': AppLocalizations.of(context).invalid,
        'value': 'Invalid',
        'count': invalid,
        'color': _T.red,
      },
      {
        'label': AppLocalizations.of(context).partiallyInvalid,
        'value': 'Partially Invalid',
        'count': partiallyInvalid,
        'color': _T.red,
      },
    ];

    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search bar (unchanged)
          Container(
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: _T.textPri, fontSize: 14),
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchByFilename,
                hintStyle: const TextStyle(color: _T.textMut, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _T.textMut,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _T.textMut,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ✅ Combined filter + count chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final active = _statusFilter == f['value'];
                final color = f['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _statusFilter = f['value'] as String);
                      _applyFilters();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active ? color.withOpacity(0.15) : _T.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? color : _T.border,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(active ? 0.25 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${f['count']}',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Label
                          Text(
                            f['label'] as String,
                            style: TextStyle(
                              color: active ? color : _T.textSec,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: _T.textMut.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).noRecordFound,
              style: TextStyle(color: _T.textMut, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      itemCount: _pageRecords.length,
      itemBuilder: (context, i) => _buildCard(_pageRecords[i], i),
    );
  }

  String _translateStatus(String status, BuildContext context) {
    switch (status) {
      case 'Pending':
        return AppLocalizations.of(context).pending;
      case 'Confirmed':
        return AppLocalizations.of(context).confirmed;
      case 'Invalid':
        return AppLocalizations.of(context).invalid;
      case 'Partially Invalid':
        return AppLocalizations.of(context).partiallyInvalid;
      default:
        return status;
    }
  }

  Widget _buildCard(SalesRecord record, int index) {
    final isPending = record.status == 'Pending';
    final statusColor = isPending ? _T.amber : _T.green;
    final timeAgo = _timeAgo(record.dateAdded);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOut,
      builder: (context, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - val)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {},
            splashColor: _T.accent.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.25)),
                    ),
                    child: Icon(
                      isPending
                          ? Icons.hourglass_top_rounded
                          : Icons.check_circle_outline_rounded,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fileName,
                          style: const TextStyle(
                            color: _T.textPri,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: _T.textMut,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: const TextStyle(
                                color: _T.textMut,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _translateStatus(record.status, context),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (record.reference.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${AppLocalizations.of(context).ref}: ${record.reference}',
                            style: const TextStyle(
                              color: _T.textMut,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action button
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: _T.textSec,
                      size: 20,
                    ),
                    color: _T.cardHover,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: _T.border),
                    ),
                    onSelected: (val) async {
                      if (val == 'view') {
                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewScreen(
                              invoiceNo: record.reference,
                              userId: auth.userId,
                            ),
                          ),
                        );
                      } else if (val == 'viewReceipt') {
                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final pdfUrl =
                            'https://igb-fems.com/LIVE/pages/get_attachment2.php'
                            '?ID=${auth.userId}&file=${record.fileName}&folder=Sales_Invoices';

                        final url =
                            'https://docs.google.com/viewer?url=${Uri.encodeComponent(pdfUrl)}&embedded=true';

                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: _T.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            insetPadding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.85,
                              child: Column(
                                children: [
                                  // Header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      8,
                                      12,
                                    ),
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
                                            AppLocalizations.of(
                                              context,
                                            ).viewReceipt,
                                            style: TextStyle(
                                              color: _T.textPri,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: _T.textSec,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(color: _T.border, height: 1),
                                  // WebView
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      child: WebViewWidget(
                                        controller: WebViewController()
                                          ..setJavaScriptMode(
                                            JavaScriptMode.unrestricted,
                                          )
                                          ..loadRequest(Uri.parse(url)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else if (val == 'delete') {
                        final ok = await _showDeleteDialog();
                        if (ok == true) _deleteRecord(record);
                      }
                    },
                    itemBuilder: (_) => [
                      if (record.status == 'Pending') ...[
                        PopupMenuItem(
                          value: 'viewReceipt',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 16,
                                color: _T.accent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context).viewReceipt,
                                style: TextStyle(
                                  color: _T.accent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: _T.red,
                              ),
                              SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context).delete,
                                style: TextStyle(color: _T.red, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        PopupMenuItem(
                          value: 'viewReceipt',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 16,
                                color: _T.accent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context).viewReceipt,
                                style: TextStyle(
                                  color: _T.accent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _T.border),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _T.red, size: 22),
            SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).deleteRecord,
              style: TextStyle(
                color: _T.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).deleteRecordConfirmation,
          style: TextStyle(color: _T.textSec, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(color: _T.textSec),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppLocalizations.of(context).delete,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${AppLocalizations.of(context).page} $_currentPage ${AppLocalizations.of(context).of_} $_totalPages',
            style: const TextStyle(color: _T.textMut, fontSize: 12),
          ),
          Row(
            children: [
              _pageBtn(
                Icons.first_page_rounded,
                _currentPage > 1,
                () => setState(() => _currentPage = 1),
              ),
              const SizedBox(width: 4),
              _pageBtn(
                Icons.chevron_left_rounded,
                _currentPage > 1,
                () => setState(() => _currentPage--),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _T.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _T.accent.withOpacity(0.3)),
                ),
                child: Text(
                  '$_currentPage',
                  style: const TextStyle(
                    color: _T.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pageBtn(
                Icons.chevron_right_rounded,
                _currentPage < _totalPages,
                () => setState(() => _currentPage++),
              ),
              const SizedBox(width: 4),
              _pageBtn(
                Icons.last_page_rounded,
                _currentPage < _totalPages,
                () => setState(() => _currentPage = _totalPages),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? _T.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? _T.border : Colors.transparent),
        ),
        child: Icon(icon, size: 18, color: enabled ? _T.textSec : _T.textMut),
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: _T.red),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).somethingWentWrong,
            style: const TextStyle(
              color: _T.textPri,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(err, style: const TextStyle(color: _T.textMut, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accent,
              elevation: 0,
            ),
            onPressed: () => setState(() => _futureRecords = _fetchRecords()),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}

// ─── View / Invoice Screen ─────────────────────────────────────────
class ViewScreen extends StatefulWidget {
  final String invoiceNo;
  final String userId;

  const ViewScreen({super.key, required this.invoiceNo, required this.userId});

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  final formatter = NumberFormat('#,##0.00');
  Map<String, dynamic>? invoiceData;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/sales_info.php'
          '?InvoiceNo=${widget.invoiceNo}&UserID=${widget.userId}',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success' &&
            data['invoices'] is List &&
            (data['invoices'] as List).isNotEmpty) {
          setState(() {
            invoiceData = data['invoices'][0];
            isLoading = false;
          });
        } else {
          setState(() {
            error = AppLocalizations.of(context).noDataFound;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'HTTP ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  double _parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.surface,
        elevation: 0,
        foregroundColor: _T.textPri,
        title: const Text(
          'Invoice Detail',
          style: TextStyle(
            color: _T.textPri,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.border),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accent))
          : error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: _T.red),
              ),
            )
          : invoiceData == null
          ? const Center(
              child: Text('No data', style: TextStyle(color: _T.textMut)),
            )
          : _buildInvoice(),
    );
  }

  Widget _buildInvoice() {
    final inv = invoiceData!;
    final status = inv['InvoiceStatus'] ?? '';
    final isConf = status == 'Confirmed';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_T.accent.withOpacity(0.2), _T.card],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _T.accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _T.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: _T.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  inv['DocumentNo'] ?? '—',
                  style: const TextStyle(
                    color: _T.textPri,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isConf
                        ? _T.green.withOpacity(0.12)
                        : _T.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isConf
                          ? _T.green.withOpacity(0.3)
                          : _T.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isConf ? _T.green : _T.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Info card ──
          _infoCard([
            _infoRow(
              Icons.person_outline_rounded,
              'Client',
              inv['ClientName'] ?? '—',
            ),
            _infoRow(
              Icons.calendar_today_rounded,
              'Date',
              inv['TransactionDate'] ?? '—',
            ),
            _infoRow(Icons.badge_outlined, 'TIN', inv['TIN'] ?? '—'),
          ]),

          const SizedBox(height: 14),

          // ── Items ──
          Container(
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.list_alt_rounded,
                        color: _T.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Line Items',
                        style: TextStyle(
                          color: _T.textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(inv['detail'] as List).length} item(s)',
                        style: const TextStyle(color: _T.textMut, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Header row
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _T.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Description',
                          style: TextStyle(
                            color: _T.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            color: _T.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          'Price',
                          style: TextStyle(
                            color: _T.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          'Total',
                          style: TextStyle(
                            color: _T.textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ...(inv['detail'] as List).asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isEven = i % 2 == 0;
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isEven
                          ? _T.surface.withOpacity(0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['Description'] ?? '',
                            style: const TextStyle(
                              color: _T.textPri,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${item['Qty']}',
                            style: const TextStyle(
                              color: _T.textSec,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            formatter.format(_parseNum(item['Price'])),
                            style: const TextStyle(
                              color: _T.textSec,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            formatter.format(_parseNum(item['Total'])),
                            style: const TextStyle(
                              color: _T.textPri,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Totals ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Column(
              children: [
                _totalRow(
                  'Subtotal',
                  formatter.format(_parseNum(inv['SubTotal'])),
                  _T.textSec,
                  false,
                ),
                const SizedBox(height: 8),
                _totalRow(
                  'Discount',
                  '- ${formatter.format(_parseNum(inv['DiscountAmount']))}',
                  _T.red,
                  false,
                ),
                const SizedBox(height: 8),
                _totalRow(
                  'Income Tax',
                  formatter.format(_parseNum(inv['2307_IT'])),
                  _T.textSec,
                  false,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: _T.border, height: 1),
                ),
                _totalRow(
                  'Grand Total',
                  '₱ ${formatter.format(_parseNum(inv['Total']))}',
                  _T.accent,
                  true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        children: rows
            .map(
              (w) =>
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: w),
            )
            .toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: _T.accent, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _T.textMut,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                color: _T.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, Color color, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? _T.textPri : _T.textSec,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 18 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
