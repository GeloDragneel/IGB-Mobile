import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  bool _showDateFilters = true;
  List<Map<String, dynamic>> _trialBalanceData = [];
  double _totalAmount = 0.0;
  double _totalAmount2 = 0.0;
  double _netVAT = 0.0;
  double _inputVAT = 0.0;
  double _VATExempt = 0.0;
  double _ZeroRated = 0.0;
  double _NonVAT = 0.0;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_dateFrom == null && auth.fromDate.isNotEmpty) {
      _dateFrom = DateTime.tryParse("${auth.fromDate}-01");
    }
    if (_dateTo == null && auth.toDate.isNotEmpty) {
      _dateTo = DateTime.tryParse("${auth.toDate}-01");
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? DateTime.now())
          : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8f72ec),
              onPrimary: Colors.white,
              surface: Color(0xFF1e2235),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  // ─── Date picker tile (reusable) ────────────────────────────────────────────
  Widget _datePickerTile({required bool isFrom, bool compact = false}) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 10 : 14,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2235),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFrom
              ? (_dateFrom != null
                    ? DateFormat("MMM yyyy").format(_dateFrom!)
                    : AppLocalizations.of(context).dateFrom)
              : (_dateTo != null
                    ? DateFormat("MMM yyyy").format(_dateTo!)
                    : AppLocalizations.of(context).dateTo),
          style: TextStyle(color: Colors.white, fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  // ─── Generate button (reusable) ──────────────────────────────────────────────
  Widget _generateButton({bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 42 : null,
      child: ElevatedButton(
        onPressed: _onGeneratePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8f72ec),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 14,
            horizontal: 24,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).generateReport,
          style: TextStyle(fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  // ─── Generate button logic (extracted) ──────────────────────────────────────
  Future<void> _onGeneratePressed() async {
    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseSelectBothDates),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final from = DateFormat('yyyy-MM').format(_dateFrom!);
    final to = DateFormat('yyyy-MM').format(_dateTo!);
    final url =
        'https://igb-fems.com/LIVE/mobile_php/sales_report.php?userId=${auth.userId}&from=$from&to=$to&branchType=${auth.branchType}&clientNum=${auth.clientNum}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          final invoices = List<Map<String, dynamic>>.from(data['invoices']);
          double totalAmount = 0.0;
          double totalAmount2 = 0.0;
          double netVAT = 0.0;
          double inputVAT = 0.0;
          double VATExempt = 0.0;
          double ZeroRated = 0.0;
          double NonVAT = 0.0;

          for (var item in invoices) {
            totalAmount += double.tryParse(item['Total'].toString()) ?? 0;
            totalAmount2 += double.tryParse(item['Total2'].toString()) ?? 0;
            netVAT += double.tryParse(item['NetOfVAT'].toString()) ?? 0;
            inputVAT += double.tryParse(item['inputVAT'].toString()) ?? 0;
            VATExempt += double.tryParse(item['VATExempt'].toString()) ?? 0;
            ZeroRated += double.tryParse(item['ZeroRated'].toString()) ?? 0;
            NonVAT += double.tryParse(item['NonVAT'].toString()) ?? 0;
          }

          setState(() {
            _trialBalanceData = invoices;
            _totalAmount = totalAmount;
            _totalAmount2 = totalAmount2;
            _netVAT = netVAT;
            _inputVAT = inputVAT;
            _VATExempt = VATExempt;
            _ZeroRated = ZeroRated;
            _NonVAT = NonVAT;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${data['result']}')));
        }
      } else {
        setState(() {
          _isLoading = false;
          _showDateFilters = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Detect orientation ──────────────────────────────────────────────────
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).salesReport),
        actions: [
          if (_trialBalanceData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              onPressed: _resetZoom,
              tooltip: AppLocalizations.of(context).resetZoom,
            ),
        ],
      ),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: Column(
        children: [
          // ── Filter section ──────────────────────────────────────────────
          if (_showDateFilters)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLandscape ? 8 : 20,
              ),
              child: isLandscape
                  // ── LANDSCAPE: all 3 controls in one row ────────────────
                  ? Row(
                      children: [
                        Expanded(
                          child: _datePickerTile(isFrom: true, compact: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _datePickerTile(isFrom: false, compact: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _generateButton(compact: true)),
                      ],
                    )
                  // ── PORTRAIT: stacked layout (original) ─────────────────
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: _datePickerTile(isFrom: true),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: _datePickerTile(isFrom: false),
                        ),
                        _generateButton(),
                      ],
                    ),
            ),

          // ── Table section ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trialBalanceData.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).noDataFound,
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 3.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    transformationController: _transformationController,
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            border: TableBorder.all(
                              color: Colors.grey.shade600,
                              width: 1,
                            ),
                            columnSpacing: 15,
                            dataRowMinHeight: 30,
                            dataRowMaxHeight: 30,
                            headingRowHeight: 30,
                            columns: [
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).date,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).tin,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).customer,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).documents,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).accountName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).amount,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).currency,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).exRate,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  'PHP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).netVAT,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).inputVAT,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).vatExempt,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).zeroRated,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                numeric: true,
                                label: Text(
                                  AppLocalizations.of(context).nonVAT,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                            rows: [
                              ..._trialBalanceData.map((item) {
                                final amount = NumberFormat('#,##0.00').format(
                                  double.tryParse(item['Total'].toString()) ??
                                      0,
                                );
                                final amount2 = NumberFormat('#,##0.00').format(
                                  double.tryParse(item['Total2'].toString()) ??
                                      0,
                                );
                                final netVAT = NumberFormat('#,##0.00').format(
                                  double.tryParse(
                                        item['NetOfVAT'].toString(),
                                      ) ??
                                      0,
                                );
                                final inputVAT = NumberFormat('#,##0.00')
                                    .format(
                                      double.tryParse(
                                            item['inputVAT'].toString(),
                                          ) ??
                                          0,
                                    );
                                final VATExempt = NumberFormat('#,##0.00')
                                    .format(
                                      double.tryParse(
                                            item['VATExempt'].toString(),
                                          ) ??
                                          0,
                                    );
                                final ZeroRated = NumberFormat('#,##0.00')
                                    .format(
                                      double.tryParse(
                                            item['ZeroRated'].toString(),
                                          ) ??
                                          0,
                                    );
                                final NonVAT = NumberFormat('#,##0.00').format(
                                  double.tryParse(item['NonVAT'].toString()) ??
                                      0,
                                );
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        item['DeclaredMonth'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['TIN'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['VendorName'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['DocumentNo'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['Account_Name'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        amount,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['Currency'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['ExRate'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        amount2,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        netVAT,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        inputVAT,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        VATExempt,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        ZeroRated,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        NonVAT,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              // ── Totals row ──────────────────────────
                              DataRow(
                                cells: [
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      AppLocalizations.of(context).total,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_totalAmount),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const DataCell(
                                    Text(
                                      '',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_totalAmount2),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat('#,##0.00').format(_netVAT),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_inputVAT),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_VATExempt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_ZeroRated),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat('#,##0.00').format(_NonVAT),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFF8f72ec),
                            ),
                            dataRowColor:
                                WidgetStateProperty.resolveWith<Color?>((
                                  Set<WidgetState> states,
                                ) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(
                                      0xFF1e2235,
                                    ).withValues(alpha: 0.5);
                                  }
                                  return const Color(0xFF1e2235);
                                }),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }
}
