import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';
import '../constants/api_constants.dart';

// ─── Theme Constants ───────────────────────────────────────────────
class _T {
  static const bg = Color(0xFF080C14);
  static const surface = Color(0xFF0F1521);
  static const card = Color(0xFF141B28);
  static const border = Color(0xFF1E2A3E);
  static const accent = Color(0xFF6C63FF);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const textPri = Color(0xFFF1F5F9);
  static const textSec = Color(0xFF94A3B8);
  static const textMut = Color(0xFF475569);
}

// ─── Deposit Record Model ──────────────────────────────────────────
class DepositRecord {
  final String paymentId;
  final String branchCode;
  final String tradeName;
  final String servicePeriod;
  final String paymentDetails;
  final double amount;
  final double coAmount;
  final double totalAmount;
  final String remarks;

  DepositRecord({
    required this.paymentId,
    required this.branchCode,
    required this.tradeName,
    required this.servicePeriod,
    required this.paymentDetails,
    required this.amount,
    required this.coAmount,
    required this.totalAmount,
    required this.remarks,
  });

  factory DepositRecord.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return DepositRecord(
      paymentId: json['PaymentID']?.toString() ?? '',
      branchCode: json['BranchCode'] ?? '',
      tradeName: json['TradeName'] ?? '',
      servicePeriod: json['ServicePeriod'] ?? '',
      paymentDetails: json['PaymentDetails'] ?? '',
      amount: d(json['Amount']),
      coAmount: d(json['COAmount']),
      totalAmount: d(json['TotalAmount']),
      remarks: json['Remarks'] ?? '',
    );
  }
}

// ─── Deposit Screen ────────────────────────────────────────────────
class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _searchCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<DepositRecord> _allRecords = [];
  List<DepositRecord> _filteredRecords = [];
  bool _recordsLoading = false;
  String _recordsError = '';

  final Set<String> _selectedPaymentIds = {};

  int _currentPage = 1;
  static const _perPage = 10;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _fetchRecords();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    if (!mounted) return;
    setState(() {
      _recordsLoading = true;
      _recordsError = '';
      _selectedPaymentIds.clear();
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/deposit_list'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final records = (data['list'] as List)
              .map((e) => DepositRecord.fromJson(e))
              .toList();
          if (mounted) {
            _searchCtrl.clear();
            setState(() {
              _allRecords = records;
              _filteredRecords = records;
              _currentPage = 1;
              _recordsLoading = false;
            });
            _animCtrl.forward(from: 0);
          }
          return;
        }
      }
      if (mounted)
        setState(() {
          _allRecords = [];
          _filteredRecords = [];
          _recordsLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _recordsError = e.toString();
          _recordsLoading = false;
        });
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredRecords = _allRecords
          .where(
            (r) =>
                q.isEmpty ||
                r.tradeName.toLowerCase().contains(q) ||
                r.paymentDetails.toLowerCase().contains(q) ||
                r.servicePeriod.toLowerCase().contains(q),
          )
          .toList();
      _currentPage = 1;
    });
  }

  int get _totalPages =>
      (_filteredRecords.length / _perPage).ceil().clamp(1, 999);

  List<DepositRecord> get _pageRecords {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _filteredRecords.length);
    return _filteredRecords.sublist(start, end);
  }

  // ─── Submit Bottom Sheet ──────────────────────────────────────────
  void _showSubmitBottomSheet() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final employeeId = auth.employeeId;

    final selected = _allRecords
        .where((r) => _selectedPaymentIds.contains(r.paymentId))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitBottomSheet(
        records: selected,
        employeeId: employeeId,
        onSubmitted: () {
          setState(() => _selectedPaymentIds.clear());
          _fetchRecords();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedPaymentIds.isNotEmpty;
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(hasSelection),
      drawer: AppDrawer(selectedIndex: 3),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
          if (!_recordsLoading && _totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────
  AppBar _buildAppBar(bool hasSelection) {
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
            AppLocalizations.of(context).deposit,
            style: const TextStyle(
              color: _T.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: hasSelection
              ? Container(
                  key: const ValueKey('submit'),
                  margin: const EdgeInsets.only(right: 12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _showSubmitBottomSheet,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      'Submit (${_selectedPaymentIds.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: _T.textPri, fontSize: 14),
          onChanged: (_) => _applySearch(),
          decoration: InputDecoration(
            hintText: 'Search by trade name, details, period…',
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
                      _applySearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_recordsLoading)
      return const Center(child: CircularProgressIndicator(color: _T.accent));
    if (_recordsError.isNotEmpty) return _buildError(_recordsError);
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
            const Text(
              'No records found.',
              style: TextStyle(color: _T.textMut, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: _pageRecords.length,
        itemBuilder: (context, i) => _buildCard(_pageRecords[i], i),
      ),
    );
  }

  // ─── Card ─────────────────────────────────────────────────────────
  Widget _buildCard(DepositRecord r, int index) {
    final isChecked = _selectedPaymentIds.contains(r.paymentId);

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isChecked ? _T.green.withOpacity(0.06) : _T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked ? _T.green.withOpacity(0.5) : _T.border,
            width: isChecked ? 1.5 : 1,
          ),
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
            onTap: () => setState(() {
              if (isChecked) {
                _selectedPaymentIds.remove(r.paymentId);
              } else {
                _selectedPaymentIds.add(r.paymentId);
              }
            }),
            splashColor: _T.green.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isChecked ? _T.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isChecked ? _T.green : _T.textMut,
                          width: 1.5,
                        ),
                      ),
                      child: isChecked
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _T.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _T.accent.withOpacity(0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.payments_outlined,
                                color: _T.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.tradeName,
                                    style: const TextStyle(
                                      color: _T.textPri,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        size: 11,
                                        color: _T.textMut,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          r.servicePeriod,
                                          style: const TextStyle(
                                            color: _T.textMut,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: _T.border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _amountCell(
                              'Amount',
                              '₱ ${_fmt.format(r.amount)}',
                              _T.textPri,
                            ),
                            _divider(),
                            _amountCell(
                              'C/O',
                              '₱ ${_fmt.format(r.coAmount)}',
                              r.coAmount > 0 ? _T.red : _T.textMut,
                            ),
                            _divider(),
                            _amountCell(
                              'Net Amount',
                              '₱ ${_fmt.format(r.totalAmount)}',
                              _T.green,
                              bold: true,
                            ),
                          ],
                        ),
                        if (r.paymentDetails.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(height: 1, color: _T.border),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_rounded,
                                size: 13,
                                color: _T.textMut,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r.paymentDetails,
                                style: const TextStyle(
                                  color: _T.textSec,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (r.remarks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 12,
                                color: _T.textMut,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  r.remarks,
                                  style: const TextStyle(
                                    color: _T.textMut,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountCell(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _T.textMut, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 28,
    color: _T.border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );

  // ─── Pagination ───────────────────────────────────────────────────
  Widget _buildPagination() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage of $_totalPages',
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
          const Text(
            'Something went wrong',
            style: TextStyle(
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
            onPressed: _fetchRecords,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Submit Bottom Sheet ───────────────────────────────────────────
class _SubmitBottomSheet extends StatefulWidget {
  final List<DepositRecord> records;
  final String employeeId;
  final VoidCallback onSubmitted;

  const _SubmitBottomSheet({
    required this.records,
    required this.employeeId,
    required this.onSubmitted,
  });

  @override
  State<_SubmitBottomSheet> createState() => _SubmitBottomSheetState();
}

class _SubmitBottomSheetState extends State<_SubmitBottomSheet> {
  final _picker = ImagePicker();
  File? _receiptFile;
  bool _isSubmitting = false;

  double get _totalSelected =>
      widget.records.fold(0, (sum, r) => sum + r.totalAmount);

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return;
      if (mounted) setState(() => _receiptFile = File(xfile.path));
    } catch (e) {
      if (mounted) _showError('Could not pick image: $e');
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final details = widget.records
        .map((r) => {'PaymentID': r.paymentId})
        .toList();

    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConstants.baseUrl}/bill_deposit'),
            )
            ..fields['EmployeeID'] = widget.employeeId
            ..fields['Details'] = json.encode(details);

      // Attach deposit slip if picked
      if (_receiptFile != null) {
        final ext = p.extension(_receiptFile!.path).toLowerCase();
        final mime = ext == '.png' ? 'image/png' : 'image/jpeg';
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _receiptFile!.path,
            contentType: MediaType.parse(mime),
          ),
        );
      }

      final streamed = await request.send();
      final resBody = await streamed.stream.bytesToString();

      if (!mounted) return;

      if (streamed.statusCode == 200) {
        Map<String, dynamic> data;
        try {
          data = json.decode(resBody);
        } catch (_) {
          _showError('Unexpected server response.');
          return;
        }

        if (data['result'] == 'Success') {
          Navigator.pop(context);
          widget.onSubmitted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Submitted ${widget.records.length} record${widget.records.length > 1 ? 's' : ''} successfully!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _T.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _showError(data['message'] ?? 'Submission failed');
        }
      } else {
        _showError('Server error ${streamed.statusCode}');
      }
    } catch (e) {
      if (mounted) _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _T.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _T.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: _T.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Submit Deposit',
                        style: TextStyle(
                          color: _T.textPri,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.records.length} record${widget.records.length > 1 ? 's' : ''} · ₱ ${fmt.format(_totalSelected)}',
                        style: const TextStyle(color: _T.textMut, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Records summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _T.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _T.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          size: 14,
                          color: _T.textMut,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.records.length} record${widget.records.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            color: _T.textSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₱ ${fmt.format(_totalSelected)}',
                          style: const TextStyle(
                            color: _T.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (widget.records.length <= 3) ...[
                      const SizedBox(height: 8),
                      Container(height: 1, color: _T.border),
                      ...widget.records.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 5,
                                color: _T.textMut,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.tradeName,
                                  style: const TextStyle(
                                    color: _T.textMut,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₱ ${fmt.format(r.totalAmount)}',
                                style: const TextStyle(
                                  color: _T.textSec,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(height: 1, color: _T.border),
              const SizedBox(height: 16),

              // ─── Deposit Slip Attachment (optional) ───────────────
              const Text(
                'DEPOSIT SLIP ATTACHMENT (OPTIONAL)',
                style: TextStyle(
                  color: _T.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickReceipt(ImageSource.camera),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _T.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _T.accent.withOpacity(0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: _T.accent,
                              size: 22,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Camera',
                              style: TextStyle(
                                color: _T.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickReceipt(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _T.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _T.amber.withOpacity(0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: _T.amber,
                              size: 22,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                color: _T.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // File preview
              if (_receiptFile != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _T.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _T.green.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _receiptFile!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.basename(_receiptFile!.path),
                          style: const TextStyle(
                            color: _T.textSec,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _T.textMut,
                        ),
                        onPressed: () => setState(() => _receiptFile = null),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _T.textSec,
                        side: const BorderSide(color: _T.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
}
