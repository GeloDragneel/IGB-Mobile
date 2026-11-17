import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';
import 'purchase_scan_dialog.dart';
import '../l10n/app_localizations.dart';
import '../constants/api_constants.dart';
import '../widgets/receipt_viewer_dialog.dart';

// ─── Theme Constants ───────────────────────────────────────────────
class _T {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Colors.white;
  static const card = Colors.white;
  static const cardHover = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const accent = Color(0xFF2563EB);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
  static const orange = Color(0xFFEA580C);
  static const textPri = Color(0xFF0F172A);
  static const textSec = Color(0xFF64748B);
  static const textMut = Color(0xFF94A3B8);
}

// ─── Model ─────────────────────────────────────────────────────────
class PurchaseRecord {
  final String fileName;
  final String status;
  final String dateAdded;
  final String reference;
  final int id;

  PurchaseRecord({
    required this.fileName,
    required this.status,
    required this.dateAdded,
    required this.reference,
    required this.id,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
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

// ─── Purchases Screen ──────────────────────────────────────────────────
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  final formatter = NumberFormat('#,##0.00');
  final _searchCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  Future<List<PurchaseRecord>> _futureRecords = Future.value([]);
  List<PurchaseRecord> _allRecords = [];
  List<PurchaseRecord> _filteredRecords = [];
  int _currentPage = 1;
  static const _perPage = 10;
  String _statusFilter = 'All';
  bool _newestFirst = true;

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

  Future<List<PurchaseRecord>> _fetchRecords() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/purchases'
        '?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}',
      ),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['result'] == 'Success') {
        final records = (data['invoices'] as List)
            .map((e) => PurchaseRecord.fromJson(e))
            .toList();
        if (mounted) {
          setState(() {
            _allRecords = records;
            _filteredRecords = [...records]
              ..sort(
                (a, b) => _newestFirst
                    ? _dateOf(b).compareTo(_dateOf(a))
                    : _dateOf(a).compareTo(_dateOf(b)),
              );
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
      _filteredRecords =
          _allRecords.where((r) {
            final matchSearch =
                q.isEmpty || r.fileName.toLowerCase().contains(q);
            final matchStatus =
                _statusFilter == 'All' || r.status == _statusFilter;
            return matchSearch && matchStatus;
          }).toList()..sort(
            (a, b) => _newestFirst
                ? _dateOf(b).compareTo(_dateOf(a))
                : _dateOf(a).compareTo(_dateOf(b)),
          );
      _currentPage = 1;
    });
  }

  DateTime _dateOf(PurchaseRecord r) =>
      DateTime.tryParse(r.dateAdded) ?? DateTime(1970);

  int get _totalPages =>
      (_filteredRecords.length / _perPage).ceil().clamp(1, 999);

  List<PurchaseRecord> get _pageRecords {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _filteredRecords.length);
    return _filteredRecords.sublist(start, end);
  }

  Future<void> _deleteRecord(PurchaseRecord record) async {
    final loc = AppLocalizations.of(context);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/delete_transaction?id=${record.id}'),
      );
      if (res.statusCode == 200) {
        _showSnack(loc.recordDeletedSuccess, _T.green);
        await _fetchRecords();
        if (!mounted) return;
        _applyFilters();
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
      drawer: AppDrawer(selectedIndex: 4),
      body: FutureBuilder<List<PurchaseRecord>>(
        future: _futureRecords,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _T.accent),
            );
          }
          if (snap.hasError) return _buildError(snap.error.toString());
          return FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildSearchAndFilter(),
                _buildTotalRow(),
                Expanded(child: _buildList()),
                if (_totalPages > 1) _buildPagination(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openScan,
              icon: const Icon(Icons.document_scanner_rounded, size: 20),
              label: Text(
                '${AppLocalizations.of(context).scan} ${AppLocalizations.of(context).purchases}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openScan() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PurchaseScanDialog(
      onUploadSuccess: () async {
        await _fetchRecords();
        if (mounted) _applyFilters();
      },
    ),
  );

  // "Total ......... 42 receipts"
  Widget _buildTotalRow() {
    final n = _filteredRecords.length;
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Text(
            'Total',
            style: TextStyle(
              color: _T.textPri,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '$n ${n == 1 ? 'receipt' : 'receipts'}',
            style: const TextStyle(
              color: _T.textPri,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _T.surface,
      surfaceTintColor: _T.surface,
      foregroundColor: _T.textPri,
      iconTheme: const IconThemeData(color: _T.textPri),
      elevation: 0,
      centerTitle: true,
      title: Text(
        AppLocalizations.of(context).purchases,
        style: const TextStyle(
          color: _T.textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _T.textSec),
          onPressed: () async {
            await _fetchRecords();
            if (mounted) _applyFilters();
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  List<Map<String, dynamic>> _filters() {
    int c(String s) => _allRecords.where((r) => r.status == s).length;
    final loc = AppLocalizations.of(context);
    return [
      {
        'label': loc.all,
        'value': 'All',
        'count': _allRecords.length,
        'color': _T.accent,
      },
      {
        'label': loc.pending,
        'value': 'Pending',
        'count': c('Pending'),
        'color': _T.amber,
      },
      {
        'label': loc.confirmed,
        'value': 'Confirmed',
        'count': c('Confirmed'),
        'color': _T.green,
      },
      {
        'label': loc.invalid,
        'value': 'Invalid',
        'count': c('Invalid'),
        'color': _T.red,
      },
      {
        'label': loc.partiallyInvalid,
        'value': 'Partially Invalid',
        'count': c('Partially Invalid'),
        'color': _T.orange,
      },
    ];
  }

  Future<void> _openFilter() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _T.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            for (final f in _filters())
              ListTile(
                onTap: () => Navigator.pop(ctx, f['value'] as String),
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: f['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  f['label'] as String,
                  style: TextStyle(
                    color: _statusFilter == f['value'] ? _T.accent : _T.textPri,
                    fontWeight: _statusFilter == f['value']
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${f['count']}',
                      style: const TextStyle(
                        color: _T.textSec,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_statusFilter == f['value']) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_rounded,
                        color: _T.accent,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _statusFilter = picked);
    _applyFilters();
  }

  Widget _buildSearchAndFilter() {
    final active = _statusFilter != 'All';
    final f = _filters().firstWhere((x) => x['value'] == _statusFilter);
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _T.bg,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Sorted by Date  ↓        filter
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _T.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sort_rounded, color: _T.textSec, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Sorted by Date',
                  style: TextStyle(
                    color: _T.textSec,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                  icon: Icon(
                    _newestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: _T.textPri,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _newestFirst = !_newestFirst);
                    _applyFilters();
                  },
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.filter_alt_rounded,
                        color: active ? f['color'] as Color : _T.textPri,
                        size: 21,
                      ),
                      onPressed: _openFilter,
                    ),
                    if (active)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: f['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('${f['label']} · ${f['count']}'),
                  labelStyle: TextStyle(
                    color: f['color'] as Color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  backgroundColor: (f['color'] as Color).withOpacity(0.08),
                  side: BorderSide(
                    color: (f['color'] as Color).withOpacity(0.3),
                  ),
                  onDeleted: () {
                    setState(() => _statusFilter = 'All');
                    _applyFilters();
                  },
                  deleteIconColor: f['color'] as Color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

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
              style: const TextStyle(color: _T.textMut, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // group this page's rows by month
    final page = _pageRecords;
    final items = <Widget>[];
    String? lastKey;
    for (var i = 0; i < page.length; i++) {
      final d = DateTime.tryParse(page[i].dateAdded);
      final key = d == null ? '—' : '${_monthNames[d.month - 1]} ${d.year}';
      if (key != lastKey) {
        final count = _filteredRecords.where((r) {
          final x = DateTime.tryParse(r.dateAdded);
          return (x == null ? '—' : '${_monthNames[x.month - 1]} ${x.year}') ==
              key;
        }).length;
        items.add(_monthHeader(key, count));
        lastKey = key;
      }
      items.add(_buildCard(page[i], i));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 8), children: items);
  }

  Widget _monthHeader(String label, int count) => Container(
    color: _T.bg,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _T.textSec,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: const TextStyle(
            color: _T.textSec,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

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

  Color _statusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return _T.green;
      case 'Invalid':
        return _T.red;
      case 'Partially Invalid':
        return _T.orange;
      default:
        return _T.amber;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Confirmed':
        return Icons.check_circle_outline_rounded;
      case 'Invalid':
        return Icons.cancel_outlined;
      case 'Partially Invalid':
        return Icons.error_outline_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  void _openReceipt(PurchaseRecord record) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // the scanned PDF comes from the new backend (S3)
    final pdfUrl =
        '${ApiConstants.baseUrl}/view_scan?id=${record.id}&userId=${auth.userId}';
    showDialog(
      context: context,
      builder: (_) => ReceiptViewerDialog(
        pdfUrl: pdfUrl,
        title: record.fileName.isNotEmpty
            ? record.fileName
            : AppLocalizations.of(context).viewReceipt,
      ),
    );
  }

  Widget _buildCard(PurchaseRecord record, int index) {
    final color = _statusColor(record.status);
    final loc = AppLocalizations.of(context);
    final d = DateTime.tryParse(record.dateAdded);
    final date = d == null ? record.dateAdded : '${d.month}/${d.day}/${d.year}';

    return Material(
      color: _T.surface,
      child: InkWell(
        onTap: () => _openReceipt(record),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _T.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _T.textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.reference.isNotEmpty
                          ? '$date · ${loc.ref}: ${record.reference}'
                          : date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _T.textMut, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _translateStatus(record.status, context),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: _T.textSec,
                  size: 20,
                ),
                color: _T.card,
                surfaceTintColor: _T.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _T.border),
                ),
                onSelected: (val) async {
                  if (val == 'viewReceipt') {
                    _openReceipt(record);
                  } else if (val == 'delete') {
                    final ok = await _showDeleteDialog();
                    if (ok == true) _deleteRecord(record);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'viewReceipt',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          size: 17,
                          color: _T.accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loc.viewReceipt,
                          style: const TextStyle(
                            color: _T.textPri,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (record.status == 'Pending')
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                            color: _T.red,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loc.delete,
                            style: const TextStyle(
                              color: _T.red,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
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
        surfaceTintColor: _T.card,
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
      decoration: const BoxDecoration(
        color: _T.surface,
        border: Border(top: BorderSide(color: _T.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
          color: enabled ? _T.bg : Colors.transparent,
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

// ─── View / Purchase Detail Screen ─────────────────────────────────
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
          '${ApiConstants.baseUrl}/purchases_info'
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
        surfaceTintColor: _T.surface,
        elevation: 0,
        foregroundColor: _T.textPri,
        title: const Text(
          'Purchase Detail',
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
          : _buildDetail(),
    );
  }

  Widget _buildDetail() {
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
                colors: [_T.accent.withOpacity(0.10), _T.card],
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
                    Icons.shopping_bag_rounded,
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
              Icons.storefront_rounded,
              'Vendor',
              inv['VendorName'] ?? '—',
            ),
            _infoRow(
              Icons.calendar_today_rounded,
              'Date',
              inv['APDate'] ?? '—',
            ),
          ]),

          const SizedBox(height: 14),

          // ── Line Items ──
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
                  return Container(
                    margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: i % 2 == 0 ? _T.bg : Colors.transparent,
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
