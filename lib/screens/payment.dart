import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

// ─── Models ────────────────────────────────────────────────────────
class ClientItem {
  final String clientNum;
  final String clientName;
  ClientItem({required this.clientNum, required this.clientName});
  factory ClientItem.fromJson(Map<String, dynamic> j) => ClientItem(
    clientNum: j['ClientNum'] ?? '',
    clientName: j['ClientName'] ?? '',
  );
}

class TradeItem {
  final String caid;
  final String tradeName;
  final String clientNum;
  TradeItem({
    required this.caid,
    required this.tradeName,
    required this.clientNum,
  });
  factory TradeItem.fromJson(Map<String, dynamic> j) => TradeItem(
    caid: j['CAID']?.toString() ?? '',
    tradeName: j['TradeName'] ?? '',
    clientNum: j['ClientNum'] ?? '',
  );
}

class PeriodItem {
  final String transID;
  final String transNumber;
  final String servicePeriod;
  final bool isPaid;
  PeriodItem({
    required this.transID,
    required this.transNumber,
    required this.servicePeriod,
    required this.isPaid,
  });
  factory PeriodItem.fromJson(Map<String, dynamic> j) => PeriodItem(
    transID: j['TransID']?.toString() ?? '',
    transNumber: j['TransNumber'] ?? '',
    servicePeriod: j['ServicePeriod'] ?? '',
    isPaid: j['IsPaid']?.toString() == '1',
  );
}

class ServiceRecord {
  final String serviceID;
  final String serListID;
  final String serFeeID;
  final String service;
  final String prepTargetDate;
  final double serviceFee;
  final String qty;
  final double less;
  final double surcharge;
  final double calServiceFeeNet;
  ServiceRecord({
    required this.serviceID,
    required this.serListID,
    required this.serFeeID,
    required this.service,
    required this.prepTargetDate,
    required this.serviceFee,
    required this.qty,
    required this.less,
    required this.surcharge,
    required this.calServiceFeeNet,
  });
  factory ServiceRecord.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ServiceRecord(
      serviceID: j['ServiceID']?.toString() ?? '',
      serListID: j['SerListID']?.toString() ?? '',
      serFeeID: j['SerFeeID']?.toString() ?? '',
      service: j['Service'] ?? '',
      prepTargetDate: j['PrepTargetDate'] ?? '',
      serviceFee: d(j['ServiceFee']),
      qty: j['QTY']?.toString() ?? '1',
      less: d(j['Less']),
      surcharge: d(j['Surcharge']),
      calServiceFeeNet: d(j['CalServiceFeeNet']),
    );
  }

  Map<String, dynamic> toPayload({
    required String caid,
    required String servicePeriod,
  }) {
    return {
      'ServiceID': serviceID,
      'SerListID': serListID,
      'SerFeeID': serFeeID,
      'CAID': caid,
      'Service': service,
      'PrepTargetDate': prepTargetDate,
      'ServiceFee': serviceFee,
      'QTY': qty,
      'Less': less,
      'Surcharge': surcharge,
      'CalServiceFeeNet': calServiceFeeNet,
      'ServicePeriod': servicePeriod,
    };
  }
}

class PaymentRecord {
  final String paymentDate;
  final String paymentType;
  final double amount;
  PaymentRecord({
    required this.paymentDate,
    required this.paymentType,
    required this.amount,
  });
  factory PaymentRecord.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return PaymentRecord(
      paymentDate: j['PaymentDate'] ?? '',
      paymentType: j['PaymentType'] ?? '',
      amount: d(j['Amount']),
    );
  }
}

class PaymentTypeItem {
  final String id;
  final String name;
  PaymentTypeItem({required this.id, required this.name});
  factory PaymentTypeItem.fromJson(Map<String, dynamic> j) => PaymentTypeItem(
    id:
        j['PayTypeID']?.toString() ??
        j['PaymentTypeID']?.toString() ??
        j['id']?.toString() ??
        '',
    name: j['PaymentType'] ?? j['name'] ?? '',
  );
}

class ChequeTypeItem {
  final String id;
  final String name;
  ChequeTypeItem({required this.id, required this.name});
  factory ChequeTypeItem.fromJson(Map<String, dynamic> j) => ChequeTypeItem(
    id: j['ChequeTypeID']?.toString() ?? j['id']?.toString() ?? '',
    name: j['ChequeType'] ?? j['name'] ?? '',
  );
}

class PaymentColTypeItem {
  final String id;
  final String name;
  PaymentColTypeItem({required this.id, required this.name});
  factory PaymentColTypeItem.fromJson(Map<String, dynamic> j) =>
      PaymentColTypeItem(
        id: j['PaymentColTypeID']?.toString() ?? '',
        name: j['PaymentColType'] ?? '',
      );
}

class ReceiptTypeItem {
  final String id;
  final String name;
  final String description;
  ReceiptTypeItem({
    required this.id,
    required this.name,
    required this.description,
  });
  factory ReceiptTypeItem.fromJson(Map<String, dynamic> j) => ReceiptTypeItem(
    id: j['ReceiptTypeID']?.toString() ?? '',
    name: j['ReceiptType'] ?? '',
    description: j['Description'] ?? '',
  );
}

// ─── Payment Screen ────────────────────────────────────────────────
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = NumberFormat('#,##0.00');
  late TabController _tabController;

  List<ClientItem> _clients = [];
  List<TradeItem> _trades = [];
  List<PeriodItem> _periods = [];

  ClientItem? _selectedClient;
  TradeItem? _selectedTrade;
  PeriodItem? _selectedPeriod;

  bool _clientsLoading = false;
  bool _tradesLoading = false;
  bool _periodsLoading = false;

  List<ServiceRecord> _services = [];
  List<PaymentRecord> _payments = [];
  bool _servicesLoading = false;
  bool _paymentsLoading = false;
  String _servicesError = '';
  String _paymentsError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchClients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    if (!mounted) return;
    setState(() => _clientsLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/client_name_list.php'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => ClientItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _clients = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _clientsLoading = false);
  }

  Future<void> _fetchTrades(String clientNum) async {
    if (!mounted) return;
    setState(() {
      _tradesLoading = true;
      _trades = [];
      _selectedTrade = null;
      _periods = [];
      _selectedPeriod = null;
      _services = [];
      _payments = [];
    });
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/client_account_list.php?ClientNum=$clientNum',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => TradeItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _trades = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _tradesLoading = false);
  }

  Future<void> _fetchPeriods(String caid) async {
    if (!mounted) return;
    setState(() {
      _periodsLoading = true;
      _periods = [];
      _selectedPeriod = null;
      _services = [];
      _payments = [];
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/service_period.php?CAID=$caid'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => PeriodItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _periods = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _periodsLoading = false);
  }

  Future<void> _fetchServices(String transNumber) async {
    if (!mounted) return;
    setState(() {
      _servicesLoading = true;
      _servicesError = '';
      _services = [];
    });
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/service_list.php?TransNumber=$transNumber',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => ServiceRecord.fromJson(e))
              .toList();
          if (mounted) setState(() => _services = list);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _servicesError = e.toString());
    }
    if (mounted) setState(() => _servicesLoading = false);
  }

  Future<void> _fetchPayments(String transNumber) async {
    if (!mounted) return;
    setState(() {
      _paymentsLoading = true;
      _paymentsError = '';
      _payments = [];
    });
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/payment_list.php?TransNumber=$transNumber',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => PaymentRecord.fromJson(e))
              .toList();
          if (mounted) setState(() => _payments = list);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _paymentsError = e.toString());
    }
    if (mounted) setState(() => _paymentsLoading = false);
  }

  void _onPeriodSelected(PeriodItem period) {
    setState(() => _selectedPeriod = period);
    _fetchServices(period.transNumber);
    _fetchPayments(period.transNumber);
  }

  void _clearAll() {
    setState(() {
      _selectedClient = null;
      _selectedTrade = null;
      _selectedPeriod = null;
      _trades = [];
      _periods = [];
      _services = [];
      _payments = [];
    });
  }

  void _showAddPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentBottomSheet(
        transNumber: _selectedPeriod?.transNumber ?? '',
        caid: _selectedTrade?.caid ?? '',
        servicePeriod: _selectedPeriod?.servicePeriod ?? '',
        services: _services,
        onSaved: (payment) {
          _clearAll();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Payment added successfully!',
                style: TextStyle(
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _buildAppBar(),
      drawer: AppDrawer(selectedIndex: 3),
      body: Column(
        children: [
          _buildDropdowns(),
          if (_selectedPeriod != null) _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
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
            AppLocalizations.of(context).payment,
            style: const TextStyle(
              color: _T.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.border),
      ),
    );
  }

  Widget _buildDropdowns() {
    return Container(
      color: _T.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Client Name'),
          const SizedBox(height: 6),
          _clientsLoading
              ? _loadingPickerField()
              : _buildPickerField(
                  hint: 'Select Client',
                  value: _selectedClient != null
                      ? '${_selectedClient!.clientNum} — ${_selectedClient!.clientName}'
                      : null,
                  enabled: true,
                  onTap: () => _openClientPicker(),
                ),
          const SizedBox(height: 12),
          _fieldLabel('Trade Name'),
          const SizedBox(height: 6),
          _tradesLoading
              ? _loadingPickerField()
              : _buildPickerField(
                  hint: 'Select Trade Name',
                  value: _selectedTrade?.tradeName,
                  enabled: _selectedClient != null,
                  onTap: _selectedClient == null
                      ? null
                      : () => _openTradePicker(),
                ),
          const SizedBox(height: 12),
          _fieldLabel('Service Period'),
          const SizedBox(height: 6),
          _periodsLoading
              ? _loadingPickerField()
              : _buildPickerField(
                  hint: 'Select Period',
                  value: _selectedPeriod?.servicePeriod,
                  enabled: _selectedTrade != null,
                  onTap: _selectedTrade == null
                      ? null
                      : () => _openPeriodPicker(),
                ),
        ],
      ),
    );
  }

  Widget _buildPickerField({
    required String hint,
    required String? value,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: enabled ? _T.card : _T.card.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value != null ? _T.textPri : _T.textMut,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: enabled ? _T.textMut : _T.textMut.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingPickerField() => Container(
    height: 46,
    decoration: BoxDecoration(
      color: _T.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _T.border),
    ),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
    ),
  );

  void _openClientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet<ClientItem>(
        title: 'Client Name',
        items: _clients,
        selected: _selectedClient,
        itemLabel: (c) => c.clientName,
        itemSublabel: (c) => c.clientNum,
        searchMatch: (c, q) =>
            c.clientName.toLowerCase().contains(q) ||
            c.clientNum.toLowerCase().contains(q),
        onSelected: (c) {
          setState(() {
            _selectedClient = c;
            _selectedTrade = null;
            _selectedPeriod = null;
            _trades = [];
            _periods = [];
            _services = [];
            _payments = [];
          });
          _fetchTrades(c.clientNum);
        },
      ),
    );
  }

  void _openTradePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet<TradeItem>(
        title: 'Trade Name',
        items: _trades,
        selected: _selectedTrade,
        itemLabel: (t) => t.tradeName,
        searchMatch: (t, q) => t.tradeName.toLowerCase().contains(q),
        onSelected: (t) {
          setState(() {
            _selectedTrade = t;
            _selectedPeriod = null;
            _periods = [];
            _services = [];
            _payments = [];
          });
          _fetchPeriods(t.caid);
        },
      ),
    );
  }

  void _openPeriodPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet<PeriodItem>(
        title: 'Service Period',
        items: _periods,
        selected: _selectedPeriod,
        itemLabel: (p) => p.servicePeriod,
        itemSublabel: (p) => p.transNumber,
        onSelected: (p) => _onPeriodSelected(p),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _T.surface,
      child: Column(
        children: [
          Container(height: 1, color: _T.border),
          TabBar(
            controller: _tabController,
            indicatorColor: _T.accent,
            indicatorWeight: 2.5,
            labelColor: _T.accent,
            unselectedLabelColor: _T.textSec,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Services'),
              Tab(text: 'Payment'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedPeriod == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 48,
              color: _T.textMut.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a period to view transactions',
              style: TextStyle(color: _T.textMut, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildServicesTab(), _buildPaymentsTab()],
    );
  }

  Widget _buildServicesTab() {
    if (_servicesLoading) {
      return const Center(child: CircularProgressIndicator(color: _T.accent));
    }
    if (_servicesError.isNotEmpty) {
      return _buildError(
        _servicesError,
        () => _fetchServices(_selectedPeriod!.transNumber),
      );
    }
    if (_services.isEmpty) {
      return _buildEmpty('No services found');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _services.length,
      itemBuilder: (context, i) => _buildServiceCard(_services[i], i),
    );
  }

  Widget _buildServiceCard(ServiceRecord s, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 50)),
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - val)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _T.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _T.accent.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.build_circle_outlined,
                      color: _T.accent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.service,
                          style: const TextStyle(
                            color: _T.textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        if (s.prepTargetDate.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 11,
                                color: _T.textMut,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                s.prepTargetDate,
                                style: const TextStyle(
                                  color: _T.textMut,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _T.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'QTY: ${s.qty}',
                      style: const TextStyle(
                        color: _T.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                    'Service Fee',
                    '₱ ${_fmt.format(s.serviceFee)}',
                    _T.textPri,
                  ),
                  _divider(),
                  _amountCell(
                    'Less',
                    '₱ ${_fmt.format(s.less)}',
                    s.less > 0 ? _T.red : _T.textMut,
                  ),
                  _divider(),
                  _amountCell(
                    'Surcharge',
                    '₱ ${_fmt.format(s.surcharge)}',
                    s.surcharge > 0 ? _T.amber : _T.textMut,
                  ),
                  _divider(),
                  _amountCell(
                    'Net',
                    '₱ ${_fmt.format(s.calServiceFeeNet)}',
                    _T.green,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _showAddPaymentSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add Payment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _paymentsLoading
              ? const Center(child: CircularProgressIndicator(color: _T.accent))
              : _paymentsError.isNotEmpty
              ? _buildError(
                  _paymentsError,
                  () => _fetchPayments(_selectedPeriod!.transNumber),
                )
              : _payments.isEmpty
              ? _buildEmpty('No payments yet')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: _payments.length,
                  itemBuilder: (context, i) =>
                      _buildPaymentCard(_payments[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(PaymentRecord p, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 50)),
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - val)),
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _T.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.green.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: _T.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.paymentType.isNotEmpty ? p.paymentType : 'Payment',
                      style: const TextStyle(
                        color: _T.textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
                        Text(
                          p.paymentDate,
                          style: const TextStyle(
                            color: _T.textMut,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₱ ${_fmt.format(p.amount)}',
                style: const TextStyle(
                  color: _T.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
              fontSize: 11,
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
    margin: const EdgeInsets.symmetric(horizontal: 6),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _T.textMut,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 52,
            color: _T.textMut.withOpacity(0.35),
          ),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: _T.textMut, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(String err, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: _T.red),
          const SizedBox(height: 10),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: _T.textPri,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(err, style: const TextStyle(color: _T.textMut, fontSize: 12)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accent,
              elevation: 0,
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Add Payment Bottom Sheet ──────────────────────────────────────
class _AddPaymentBottomSheet extends StatefulWidget {
  final ValueChanged<PaymentRecord> onSaved;
  final String transNumber;
  final String caid;
  final String servicePeriod;
  final List<ServiceRecord> services;

  const _AddPaymentBottomSheet({
    required this.onSaved,
    required this.transNumber,
    required this.caid,
    required this.servicePeriod,
    required this.services,
  });

  @override
  State<_AddPaymentBottomSheet> createState() => _AddPaymentBottomSheetState();
}

class _AddPaymentBottomSheetState extends State<_AddPaymentBottomSheet> {
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _chequeDateCtrl = TextEditingController();
  final _arNumberCtrl = TextEditingController();
  final _apNumberCtrl = TextEditingController();
  final _orNumberCtrl = TextEditingController();

  DateTime? _paymentDate;
  PaymentTypeItem? _paymentType;
  ChequeTypeItem? _chequeType;
  PaymentColTypeItem? _paymentColType;
  ReceiptTypeItem? _receiptType;

  List<PaymentTypeItem> _paymentTypes = [];
  bool _paymentTypesLoading = false;

  List<ChequeTypeItem> _chequeTypes = [];
  bool _chequeTypesLoading = false;

  List<PaymentColTypeItem> _paymentColTypes = [];
  bool _paymentColTypesLoading = false;

  List<ReceiptTypeItem> _receiptTypes = [];
  bool _receiptTypesLoading = false;

  bool _isSaving = false;

  bool get _isCheque => _paymentType?.id == '2';
  bool get _isBank =>
      _paymentType?.id == '3' ||
      _paymentType?.id == '4' ||
      _paymentType?.id == '5';

  @override
  void initState() {
    super.initState();
    _fetchPaymentTypes();
    _fetchChequeTypes();
    _fetchPaymentColTypes();
    _fetchReceiptTypes();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    _refCtrl.dispose();
    _chequeDateCtrl.dispose();
    _arNumberCtrl.dispose();
    _apNumberCtrl.dispose();
    _orNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentTypes() async {
    if (!mounted) return;
    setState(() => _paymentTypesLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/payment_type_list.php'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => PaymentTypeItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _paymentTypes = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _paymentTypesLoading = false);
  }

  Future<void> _fetchChequeTypes() async {
    if (!mounted) return;
    setState(() => _chequeTypesLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/cheque_type_list.php'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => ChequeTypeItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _chequeTypes = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _chequeTypesLoading = false);
  }

  Future<void> _fetchPaymentColTypes() async {
    if (!mounted) return;
    setState(() => _paymentColTypesLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/payment_col_type.php'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => PaymentColTypeItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _paymentColTypes = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _paymentColTypesLoading = false);
  }

  Future<void> _fetchReceiptTypes() async {
    if (!mounted) return;
    setState(() => _receiptTypesLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/payment_receipt_type.php'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'Success') {
          final list = (data['list'] as List)
              .map((e) => ReceiptTypeItem.fromJson(e))
              .toList();
          if (mounted) setState(() => _receiptTypes = list);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _receiptTypesLoading = false);
  }

  Future<void> _pickDate(
    BuildContext context, {
    bool isChequeDt = false,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _T.accent,
            surface: _T.card,
            onSurface: _T.textPri,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isChequeDt) {
        _chequeDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      } else {
        _paymentDate = picked;
      }
    });
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

  // ─── FIXED _save: sends flat POST fields, shows raw response on error ─
  Future<void> _save() async {
    if (_paymentDate == null ||
        _paymentType == null ||
        _amountCtrl.text.trim().isEmpty) {
      _showError('Please fill in Payment Date, Method and Amount');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      _showError('Amount must be greater than zero');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final employeeId = auth.employeeId;

    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/bill_payment.php');

      // ── All values must be strings for multipart/form-data ──────────
      final body = <String, String>{
        'PaymentDate': DateFormat('yyyy-MM-dd').format(_paymentDate!),
        'PaymentTypeID': _paymentType!.id,
        'ChequeTypeID': _chequeType?.id ?? '',
        'ChequeTypeDate': _chequeDateCtrl.text.trim(),
        'BankDigitalWallet': _bankCtrl.text.trim(),
        'ReferenceChequeNo': _refCtrl.text.trim(),
        'CAID': widget.caid,
        'PaymentColType': _paymentColType?.id ?? '',
        'ARNumber': _arNumberCtrl.text.trim(),
        'APNumber': _apNumberCtrl.text.trim(),
        'ORNumber': _orNumberCtrl.text.trim(),
        'ReceiptTypeID': _receiptType?.id ?? '',
        'Amount': amount.toStringAsFixed(2),
        'TransNumber': widget.transNumber,
        'ServicePeriod': widget.servicePeriod,
        'EmployeeID': employeeId,
      };

      debugPrint('=== POST to $uri ===');
      body.forEach((k, v) => debugPrint('  $k = $v'));

      final response = await http.post(uri, body: body);

      debugPrint('=== RESPONSE ${response.statusCode} ===');
      debugPrint(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
        } catch (_) {
          // Server returned non-JSON (PHP error / HTML)
          _showError('Server returned unexpected response. Check logs.');
          return;
        }

        if (data['result'] == 'Success') {
          final record = PaymentRecord(
            paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate!),
            paymentType: _paymentType!.name,
            amount: amount,
          );
          Navigator.pop(context);
          widget.onSaved(record);
        } else {
          _showError(data['message'] ?? 'Failed to save payment');
        }
      } else {
        _showError('Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
                      Icons.add_card_rounded,
                      color: _T.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Payment',
                        style: TextStyle(
                          color: _T.textPri,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Fill in payment details',
                        style: TextStyle(color: _T.textMut, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Payment Date ──────────────────────────────────────
              _fieldLabel('Payment Date *'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _pickDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _T.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _T.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: _T.textMut,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _paymentDate != null
                            ? DateFormat('MMMM dd, yyyy').format(_paymentDate!)
                            : 'Select date',
                        style: TextStyle(
                          color: _paymentDate != null ? _T.textPri : _T.textMut,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Payment Method ────────────────────────────────────
              _fieldLabel('Payment Method *'),
              const SizedBox(height: 6),
              _paymentTypesLoading
                  ? _loadingField()
                  : _buildSheetDropdown<PaymentTypeItem>(
                      hint: 'Select method',
                      value: _paymentType,
                      items: _paymentTypes,
                      itemLabel: (m) => m.name,
                      onChanged: (m) => setState(() {
                        _paymentType = m;
                        _chequeType = null;
                      }),
                    ),
              const SizedBox(height: 14),

              // ── Cheque-only fields ────────────────────────────────
              if (_isCheque) ...[
                _fieldLabel('Cheque Type'),
                const SizedBox(height: 6),
                _chequeTypesLoading
                    ? _loadingField()
                    : _buildSheetDropdown<ChequeTypeItem>(
                        hint: 'Select cheque type',
                        value: _chequeType,
                        items: _chequeTypes,
                        itemLabel: (c) => c.name,
                        onChanged: (c) => setState(() => _chequeType = c),
                      ),
                const SizedBox(height: 14),

                _fieldLabel('Cheque Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickDate(context, isChequeDt: true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _T.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _T.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: _T.textMut,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _chequeDateCtrl.text.isNotEmpty
                              ? _chequeDateCtrl.text
                              : 'Select date',
                          style: TextStyle(
                            color: _chequeDateCtrl.text.isNotEmpty
                                ? _T.textPri
                                : _T.textMut,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Bank / Wallet ─────────────────────────────────────
              if (_isCheque || _isBank) ...[
                _fieldLabel('Bank / Wallet'),
                const SizedBox(height: 6),
                _buildTextField(_bankCtrl, 'e.g. BDO, GCash, BPI'),
                const SizedBox(height: 14),

                _fieldLabel('Reference / Cheque #'),
                const SizedBox(height: 6),
                _buildTextField(_refCtrl, 'Reference or cheque number'),
                const SizedBox(height: 14),
              ],

              // ── Amount ────────────────────────────────────────────
              _fieldLabel('Amount *'),
              const SizedBox(height: 6),
              _buildTextField(
                _amountCtrl,
                '0.00',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // ── Payment Col Type ──────────────────────────────────
              _fieldLabel('Payment Col Type'),
              const SizedBox(height: 6),
              _paymentColTypesLoading
                  ? _loadingField()
                  : _buildSheetDropdown<PaymentColTypeItem>(
                      hint: 'Select col type',
                      value: _paymentColType,
                      items: _paymentColTypes,
                      itemLabel: (p) => p.name,
                      onChanged: (p) => setState(() => _paymentColType = p),
                    ),
              const SizedBox(height: 14),

              // ── Receipt Type ──────────────────────────────────────
              _fieldLabel('Receipt Type'),
              const SizedBox(height: 6),
              _receiptTypesLoading
                  ? _loadingField()
                  : _buildSheetDropdown<ReceiptTypeItem>(
                      hint: 'Select receipt type',
                      value: _receiptType,
                      items: _receiptTypes,
                      itemLabel: (r) => '${r.name} — ${r.description}',
                      onChanged: (r) => setState(() {
                        _receiptType = r;
                        _arNumberCtrl.clear();
                        _apNumberCtrl.clear();
                        _orNumberCtrl.clear();
                      }),
                    ),
              const SizedBox(height: 14),

              // ── AR Number ─────────────────────────────────────────
              _fieldLabel('AR Number'),
              const SizedBox(height: 6),
              _buildTextField(_arNumberCtrl, 'Acknowledgement Receipt No.'),
              const SizedBox(height: 14),

              // ── AP Number ─────────────────────────────────────────
              _fieldLabel('AP Number'),
              const SizedBox(height: 6),
              _buildTextField(_apNumberCtrl, 'Advance Payment No.'),
              const SizedBox(height: 14),

              // ── OR Number ─────────────────────────────────────────
              _fieldLabel('OR Number'),
              const SizedBox(height: 6),
              _buildTextField(_orNumberCtrl, 'Official Receipt No.'),
              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
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
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Payment',
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

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _T.textMut,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );

  Widget _loadingField() => Container(
    height: 46,
    decoration: BoxDecoration(
      color: _T.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _T.border),
    ),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: _T.textPri, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _T.textMut, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSheetDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: const TextStyle(color: _T.textMut, fontSize: 13),
        ),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: _T.card,
        icon: const Icon(
          Icons.expand_more_rounded,
          color: _T.textMut,
          size: 20,
        ),
        style: const TextStyle(color: _T.textPri, fontSize: 13),
        onChanged: onChanged,
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  style: const TextStyle(color: _T.textPri, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Search Picker Sheet ───────────────────────────────────────────
class _SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T) itemLabel;
  final String Function(T)? itemSublabel;
  final bool Function(T, String)? searchMatch;
  final ValueChanged<T> onSelected;

  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.onSelected,
    this.itemSublabel,
    this.searchMatch,
  });

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final _searchCtrl = TextEditingController();
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((item) {
              if (widget.searchMatch != null)
                return widget.searchMatch!(item, q);
              return widget.itemLabel(item).toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = widget.searchMatch != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _T.textPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _T.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _T.border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _T.textMut,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (hasSearch) ...[
              Container(
                decoration: BoxDecoration(
                  color: _T.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: _T.textPri, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.title.toLowerCase()}…',
                    hintStyle: const TextStyle(color: _T.textMut, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _T.textMut,
                      size: 18,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _T.textMut,
                            ),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: _T.textMut,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No results found',
                            style: TextStyle(color: _T.textMut, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Container(
                        height: 1,
                        color: _T.border.withOpacity(0.6),
                      ),
                      itemBuilder: (context, i) {
                        final item = _filtered[i];
                        final isSelected =
                            widget.selected != null &&
                            widget.itemLabel(widget.selected as T) ==
                                widget.itemLabel(item);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelected(item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.itemLabel(item),
                                          style: TextStyle(
                                            color: isSelected
                                                ? _T.accent
                                                : _T.textPri,
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (widget.itemSublabel != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.itemSublabel!(item),
                                            style: const TextStyle(
                                              color: _T.textMut,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: _T.accent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
