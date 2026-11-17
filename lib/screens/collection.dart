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

// ─── Payment Type Model ────────────────────────────────────────────
class PaymentType {
  final String id;
  final String name;
  PaymentType({required this.id, required this.name});
  factory PaymentType.fromJson(Map<String, dynamic> j) =>
      PaymentType(id: j['PayTypeID'].toString(), name: j['PaymentType'] ?? '');
}

// ─── Bank Name Model ───────────────────────────────────────────────
class BankName {
  final String abaId;
  final String abbrev;
  final String description;
  BankName({
    required this.abaId,
    required this.abbrev,
    required this.description,
  });
  factory BankName.fromJson(Map<String, dynamic> j) => BankName(
    abaId: j['ABAID'].toString(),
    abbrev: j['BankNameAbb'] ?? '',
    description: j['BankNameDes'] ?? '',
  );
}

// ─── Bank Account Model ────────────────────────────────────────────
class BankAccount {
  final String baId;
  final String accountName;
  final String accountNumber;
  final String accountNumberDisplay;
  BankAccount({
    required this.baId,
    required this.accountName,
    required this.accountNumber,
    required this.accountNumberDisplay,
  });
  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
    baId: j['BAID'].toString(),
    accountName: j['AccountName'] ?? '',
    accountNumber: j['AccountNumber'] ?? '',
    accountNumberDisplay: j['AccountNumberDisplay'] ?? '',
  );
}

// ─── Collection Record Model ───────────────────────────────────────
class CollectionRecord {
  final String paymentId;
  final String tradeName;
  final String servicePeriod;
  final String paymentColType;
  final String paymentDate;
  final String arNumber;
  final double amount;
  final double coAmount;
  final double totalAmount;
  final String details1;
  final String details2;
  final String clientNum;
  final String remarks;

  CollectionRecord({
    required this.paymentId,
    required this.tradeName,
    required this.servicePeriod,
    required this.paymentColType,
    required this.paymentDate,
    required this.arNumber,
    required this.amount,
    required this.coAmount,
    required this.totalAmount,
    required this.details1,
    required this.details2,
    required this.clientNum,
    required this.remarks,
  });

  factory CollectionRecord.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return CollectionRecord(
      paymentId: json['PaymentID']?.toString() ?? '',
      tradeName: json['TradeName'] ?? '',
      servicePeriod: json['ServicePeriod'] ?? '',
      paymentColType: json['PaymentColType'] ?? '',
      paymentDate: json['PaymentDate'] ?? '',
      arNumber: json['ARNumber']?.toString() ?? '',
      amount: d(json['Amount']),
      coAmount: d(json['COAmount']),
      totalAmount: d(json['TotalAmount']),
      details1: json['Details1'] ?? '',
      details2: json['Details2'] ?? '',
      clientNum: json['ClientNum'] ?? '',
      remarks: json['Remarks'] ?? '',
    );
  }
}

// ─── Collection Screen ─────────────────────────────────────────────
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,##0.00');
  final _searchCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<PaymentType> _paymentTypes = [];
  bool _typesLoading = true;
  String _selectedTypeId = '1';

  List<CollectionRecord> _allRecords = [];
  List<CollectionRecord> _filteredRecords = [];
  bool _recordsLoading = false;
  String _recordsError = '';

  final Set<String> _selectedPaymentIds = {};

  int _currentPage = 1;
  static const _perPage = 10;

  static const _chipColors = [
    _T.accent,
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
  ];
  Color _chipColor(int i) => _chipColors[i % _chipColors.length];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _fetchPaymentTypes();
    if (_paymentTypes.isNotEmpty) {
      _selectedTypeId = _paymentTypes.first.id;
      await _fetchRecords(_selectedTypeId);
    }
  }

  Future<void> _fetchPaymentTypes() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/payment_type_list'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final types = (data['list'] as List)
              .map((e) => PaymentType.fromJson(e))
              .toList();
          if (mounted)
            setState(() {
              _paymentTypes = types;
              _typesLoading = false;
            });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _typesLoading = false);
  }

  Future<void> _fetchRecords(String payTypeId) async {
    if (!mounted) return;
    setState(() {
      _recordsLoading = true;
      _recordsError = '';
      _selectedPaymentIds.clear();
    });
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/collection_list'
          '?PaymentTypeID=$payTypeId',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final records = (data['list'] as List)
              .map((e) => CollectionRecord.fromJson(e))
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
                r.arNumber.toLowerCase().contains(q) ||
                r.servicePeriod.toLowerCase().contains(q),
          )
          .toList();
      _currentPage = 1;
    });
  }

  int get _totalPages =>
      (_filteredRecords.length / _perPage).ceil().clamp(1, 999);

  List<CollectionRecord> get _pageRecords {
    final start = (_currentPage - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _filteredRecords.length);
    return _filteredRecords.sublist(start, end);
  }

  void _showSubmitBottomSheet() {
    final selected = _allRecords
        .where((r) => _selectedPaymentIds.contains(r.paymentId))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitBottomSheet(
        records: selected,
        selectedTypeId: _selectedTypeId,
        onSubmitted: () {
          setState(() => _selectedPaymentIds.clear());
          _fetchRecords(_selectedTypeId);
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
      // ─── Upload FAB ───────────────────────────────────────────────
      body: _typesLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accent))
          : Column(
              children: [
                _buildTabBar(),
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
            AppLocalizations.of(context).collection,
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

  // ─── Tab Bar ──────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_paymentTypes.length, (i) {
            final pt = _paymentTypes[i];
            final active = _selectedTypeId == pt.id;
            final color = _chipColor(i);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_selectedTypeId == pt.id) return;
                  setState(() => _selectedTypeId = pt.id);
                  _fetchRecords(pt.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
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
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? color : _T.textMut,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        pt.name,
                        style: TextStyle(
                          color: active ? color : _T.textSec,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
            hintText: 'Search by trade name, AR#, period…',
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
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          80,
        ), // extra bottom for FAB
        itemCount: _pageRecords.length,
        itemBuilder: (context, i) => _buildCard(_pageRecords[i], i),
      ),
    );
  }

  // ─── Card ─────────────────────────────────────────────────────────
  Widget _buildCard(CollectionRecord r, int index) {
    final tabIdx = _paymentTypes.indexWhere((p) => p.id == _selectedTypeId);
    final typeColor = _chipColor(tabIdx < 0 ? 0 : tabIdx);
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
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: typeColor.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.payments_outlined,
                                color: typeColor,
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
                                        Icons.tag_rounded,
                                        size: 11,
                                        color: _T.textMut,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'AR# ${r.arNumber}',
                                        style: const TextStyle(
                                          color: _T.textMut,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                            if (r.paymentColType.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: typeColor.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  r.paymentColType,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
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
                        const SizedBox(height: 10),
                        Container(height: 1, color: _T.border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              size: 13,
                              color: _T.textMut,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.paymentDate,
                              style: const TextStyle(
                                color: _T.textSec,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            if (r.details1.isNotEmpty) ...[
                              const Icon(
                                Icons.account_balance_rounded,
                                size: 13,
                                color: _T.textMut,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r.details1,
                                style: const TextStyle(
                                  color: _T.textSec,
                                  fontSize: 11,
                                ),
                              ),
                              if (r.details2.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '· ${r.details2}',
                                  style: const TextStyle(
                                    color: _T.textMut,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
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
            onPressed: () => _fetchRecords(_selectedTypeId),
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
  final List<CollectionRecord> records;
  final String selectedTypeId;
  final VoidCallback onSubmitted;

  const _SubmitBottomSheet({
    required this.records,
    required this.selectedTypeId,
    required this.onSubmitted,
  });

  @override
  State<_SubmitBottomSheet> createState() => _SubmitBottomSheetState();
}

class _SubmitBottomSheetState extends State<_SubmitBottomSheet> {
  List<BankName> _bankNames = [];
  List<BankAccount> _bankAccounts = [];
  bool _bankNamesLoading = true;
  bool _bankAccountsLoading = false;
  bool _isSubmitting = false;

  BankName? _selectedBank;
  BankAccount? _selectedAccount;

  // ─── Receipt attachment ───────────────────────────────────────────
  final _picker = ImagePicker();
  File? _receiptFile;

  @override
  void initState() {
    super.initState();
    _fetchBankNames();
  }

  Future<void> _fetchBankNames() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/bank_name_list'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final banks = (data['list'] as List)
              .map((e) => BankName.fromJson(e))
              .toList();
          if (mounted)
            setState(() {
              _bankNames = banks;
              _bankNamesLoading = false;
            });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _bankNamesLoading = false);
  }

  Future<void> _fetchBankAccounts(String abaId) async {
    if (!mounted) return;
    setState(() {
      _bankAccountsLoading = true;
      _selectedAccount = null;
      _bankAccounts = [];
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/bank_account_list?ABAID=$abaId'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final accounts = (data['list'] as List)
              .map((e) => BankAccount.fromJson(e))
              .toList();
          if (mounted)
            setState(() {
              _bankAccounts = accounts;
              _bankAccountsLoading = false;
            });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _bankAccountsLoading = false);
  }

  bool get _isValid => _selectedBank != null && _selectedAccount != null;
  double get _totalAmount => widget.records.fold(0, (s, r) => s + r.amount);
  double get _totalCO => widget.records.fold(0, (s, r) => s + r.coAmount);
  double get _totalNetAmount =>
      widget.records.fold(0, (s, r) => s + r.totalAmount);

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
    if (!_isValid) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final employeeId = auth.employeeId;

    setState(() => _isSubmitting = true);

    final details = widget.records
        .map((r) => {'PaymentID': r.paymentId})
        .toList();

    try {
      // Always use MultipartRequest so we can optionally attach the receipt file
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConstants.baseUrl}/bill_collection'),
            )
            ..fields['PaymentType'] = widget.selectedTypeId
            ..fields['CollectionType'] = ''
            ..fields['BankNameID'] = _selectedBank!.abaId
            ..fields['AssignedBank'] = _selectedAccount!.baId
            ..fields['AssignedBankDate'] = DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now())
            ..fields['AssignedBankBy'] = employeeId
            ..fields['TotalAmount'] = _totalAmount.toStringAsFixed(2)
            ..fields['TotalCO'] = _totalCO.toStringAsFixed(2)
            ..fields['TotalNetAmount'] = _totalNetAmount.toStringAsFixed(2)
            ..fields['Details'] = json.encode(details);

      // Attach receipt if the user picked one
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
          _showError('Unexpected server response. Check logs.');
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

  void _showBankNamePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _T.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: _T.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Bank',
                          style: TextStyle(
                            color: _T.textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: _T.border),
                  ],
                ),
              ),
              Expanded(
                child: _bankNamesLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _T.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _bankNames.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: _T.border),
                        itemBuilder: (_, i) {
                          final b = _bankNames[i];
                          final isSelected = _selectedBank?.abaId == b.abaId;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedBank = b);
                              _fetchBankAccounts(b.abaId);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _T.accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        b.abbrev,
                                        style: const TextStyle(
                                          color: _T.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      b.description,
                                      style: const TextStyle(
                                        color: _T.textPri,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _T.green,
                                          size: 20,
                                        )
                                      : const Icon(
                                          Icons.chevron_right,
                                          color: _T.textMut,
                                          size: 18,
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBankAccountPicker() {
    if (_selectedBank == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _T.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.credit_card_rounded,
                            color: _T.green,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Account',
                                style: TextStyle(
                                  color: _T.textPri,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_selectedBank!.abbrev} · ${_selectedBank!.description}',
                                style: const TextStyle(
                                  color: _T.textMut,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: _T.border),
                  ],
                ),
              ),
              Expanded(
                child: _bankAccountsLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _T.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : _bankAccounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 44,
                              color: _T.textMut.withOpacity(0.4),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No accounts available',
                              style: TextStyle(color: _T.textMut, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _bankAccounts.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: _T.border),
                        itemBuilder: (_, i) {
                          final a = _bankAccounts[i];
                          final isSelected = _selectedAccount?.baId == a.baId;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedAccount = a);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _T.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.credit_card_rounded,
                                      color: _T.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.accountName,
                                          style: const TextStyle(
                                            color: _T.textPri,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          a.accountNumberDisplay,
                                          style: const TextStyle(
                                            color: _T.textMut,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _T.green,
                                          size: 20,
                                        )
                                      : const Icon(
                                          Icons.chevron_right,
                                          color: _T.textMut,
                                          size: 18,
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _T.accent,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPickerField({
    required String hint,
    required String? value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: _T.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value ?? hint,
                  style: TextStyle(
                    color: value == null ? _T.textMut : _T.textPri,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.expand_more, color: _T.textMut, size: 18),
            ],
          ),
        ),
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
                        'Submit Collection',
                        style: TextStyle(
                          color: _T.textPri,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.records.length} record${widget.records.length > 1 ? 's' : ''} · ₱ ${fmt.format(_totalNetAmount)}',
                        style: const TextStyle(color: _T.textMut, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                          '₱ ${fmt.format(_totalNetAmount)}',
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
              const SizedBox(height: 20),
              _buildSectionLabel('BANK NAME'),
              const SizedBox(height: 8),
              _buildPickerField(
                hint: 'Select bank',
                value: _selectedBank != null
                    ? '${_selectedBank!.abbrev} · ${_selectedBank!.description}'
                    : null,
                icon: Icons.account_balance_rounded,
                iconColor: _T.accent,
                onTap: _showBankNamePicker,
              ),
              const SizedBox(height: 14),
              _buildSectionLabel('BANK ACCOUNT'),
              const SizedBox(height: 8),
              _buildPickerField(
                hint: _selectedBank == null
                    ? 'Select a bank first'
                    : 'Select account',
                value: _selectedAccount != null
                    ? '${_selectedAccount!.accountName}  ·  ${_selectedAccount!.accountNumberDisplay}'
                    : null,
                icon: Icons.credit_card_rounded,
                iconColor: _T.green,
                onTap: _showBankAccountPicker,
                enabled: _selectedBank != null,
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _T.border),
              const SizedBox(height: 16),

              // ─── Receipt Attachment (optional) ────────────────────
              _buildSectionLabel('RECEIPT ATTACHMENT (OPTIONAL)'),
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
                      onPressed: (_isValid && !_isSubmitting) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValid ? _T.green : _T.border,
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

// ─── Upload Deposit Sheet ──────────────────────────────────────────
class _UploadDepositSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onUploaded;

  const _UploadDepositSheet({required this.userId, required this.onUploaded});

  @override
  State<_UploadDepositSheet> createState() => _UploadDepositSheetState();
}

class _UploadDepositSheetState extends State<_UploadDepositSheet> {
  final _picker = ImagePicker();
  File? _pickedFile;
  bool _isUploading = false;
  String? _errorMsg;

  Future<void> _pick(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return;
      if (mounted)
        setState(() {
          _pickedFile = File(xfile.path);
          _errorMsg = null;
        });
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Could not pick file: $e');
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) return;
    setState(() {
      _isUploading = true;
      _errorMsg = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/upload_collection_deposit',
      );

      final ext = p.extension(_pickedFile!.path).toLowerCase();
      final mime = ext == '.png' ? 'image/png' : 'image/jpeg';

      final request = http.MultipartRequest('POST', uri)
        ..fields['userId'] = widget.userId
        ..fields['billType'] = 'Collection'
        ..fields['tableName'] = 'tbl2_collection_deposit_file'
        ..fields['tableId'] = '0'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            _pickedFile!.path,
            contentType: MediaType.parse(mime),
          ),
        );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (!mounted) return;

      final data = json.decode(body) as Map<String, dynamic>;

      if (streamed.statusCode == 200 && data['result'] == 'Success') {
        Navigator.pop(context);
        widget.onUploaded();
      } else {
        setState(() => _errorMsg = data['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    color: _T.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: _T.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Deposit File',
                      style: TextStyle(
                        color: _T.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Take a photo or pick from gallery',
                      style: TextStyle(color: _T.textMut, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Source buttons
            Row(
              children: [
                Expanded(
                  child: _sourceBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: _T.accent,
                    onTap: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sourceBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: _T.amber,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            // Preview
            if (_pickedFile != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
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
                        _pickedFile!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(_pickedFile!.path),
                            style: const TextStyle(
                              color: _T.textPri,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<int>(
                            future: _pickedFile!.length(),
                            builder: (_, snap) {
                              final kb = snap.hasData
                                  ? (snap.data! / 1024).toStringAsFixed(1)
                                  : '…';
                              return Text(
                                '$kb KB',
                                style: const TextStyle(
                                  color: _T.textMut,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _T.textMut,
                      ),
                      onPressed: () => setState(() => _pickedFile = null),
                    ),
                  ],
                ),
              ),
            ],

            // Error
            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: _T.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: _T.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading
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
                    onPressed: (_pickedFile != null && !_isUploading)
                        ? _upload
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pickedFile != null
                          ? _T.accent
                          : _T.border,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Upload',
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
    );
  }

  Widget _sourceBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
