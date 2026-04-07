import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

class PurchaseReceiptsJournalScreen extends StatefulWidget {
  const PurchaseReceiptsJournalScreen({super.key});

  @override
  State<PurchaseReceiptsJournalScreen> createState() =>
      _PurchaseReceiptsJournalScreenState();
}

class _PurchaseReceiptsJournalScreenState
    extends State<PurchaseReceiptsJournalScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  bool _showDateFilters = true;
  List<Map<String, dynamic>> _trialBalanceData = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  final TransformationController _transformationController =
      TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

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

  // ─── Date picker tile ────────────────────────────────────────────────────────
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

  // ─── Shared button style ─────────────────────────────────────────────────────
  ButtonStyle _buttonStyle({bool compact = false}) => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF8f72ec),
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14, horizontal: 24),
  );

  // ─── Generate button ─────────────────────────────────────────────────────────
  Widget _generateButton({bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 42 : null,
      child: ElevatedButton(
        onPressed: () async {
          if (_dateFrom == null || _dateTo == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).pleaseSelectBothDates,
                ),
              ),
            );
            return;
          }
          setState(() {
            _isLoading = true;
          });
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final from = DateFormat('yyyy-MM').format(_dateFrom!);
          final to = DateFormat('yyyy-MM').format(_dateTo!);
          final url =
              'https://igb-fems.com/LIVE/mobile_php/purchase_receipt_journal.php?userId=${auth.userId}&from=$from&to=$to';
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['result'] == 'Success') {
                final invoices = List<Map<String, dynamic>>.from(
                  data['invoices'],
                );
                double totalDebit = 0.0;
                double totalCredit = 0.0;

                for (var item in invoices) {
                  totalDebit += double.tryParse(item['Debit'].toString()) ?? 0;
                  totalCredit +=
                      double.tryParse(item['Credit'].toString()) ?? 0;
                }
                setState(() {
                  _trialBalanceData = invoices;
                  _totalDebit = totalDebit;
                  _totalCredit = totalCredit;
                  _isLoading = false;
                  _showDateFilters = false;
                });
              } else {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${data['result']}')),
                );
              }
            } else {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
              );
            }
          } catch (error) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
        },
        style: _buttonStyle(compact: compact),
        child: Text(
          AppLocalizations.of(context).generateReport,
          style: TextStyle(fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  // ─── Reset button ────────────────────────────────────────────────────────────
  Widget _resetButton({bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 42 : null,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _showDateFilters = true;
            _trialBalanceData = [];
            _dateFrom = null;
            _dateTo = null;
          });
        },
        style: _buttonStyle(compact: compact),
        child: Text(
          AppLocalizations.of(context).reset,
          style: TextStyle(fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Detect orientation ────────────────────────────────────────────────────
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).purchaseReceiptsJournal),
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
          // ── Filter / Reset section ────────────────────────────────────────
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLandscape ? 8 : 20,
              ),
              child: isLandscape
                  // ── LANDSCAPE ─────────────────────────────────────────────
                  ? Row(
                      children: [
                        if (_showDateFilters) ...[
                          Expanded(
                            child: _datePickerTile(isFrom: true, compact: true),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _datePickerTile(
                              isFrom: false,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _generateButton(compact: true)),
                        ] else ...[
                          Expanded(child: _resetButton(compact: true)),
                        ],
                      ],
                    )
                  // ── PORTRAIT ──────────────────────────────────────────────
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showDateFilters) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: _datePickerTile(isFrom: true),
                          ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            child: _datePickerTile(isFrom: false),
                          ),
                          _generateButton(),
                        ] else ...[
                          _resetButton(),
                        ],
                      ],
                    ),
            ),
          ),
          // ── Table section ─────────────────────────────────────────────────
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
                                  AppLocalizations.of(context).accountId,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).invoiceCMNo,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  AppLocalizations.of(context).lineDescription,
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
                                  AppLocalizations.of(context).debit,
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
                                  AppLocalizations.of(context).credit,
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
                                final debitValue =
                                    double.tryParse(item['Debit'].toString()) ??
                                    0;
                                final creditValue =
                                    double.tryParse(
                                      item['Credit'].toString(),
                                    ) ??
                                    0;

                                final debit = debitValue == 0
                                    ? ''
                                    : NumberFormat(
                                        '#,##0.00',
                                      ).format(debitValue);
                                final credit = creditValue == 0
                                    ? ''
                                    : NumberFormat(
                                        '#,##0.00',
                                      ).format(creditValue);

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        item['TransactionDate'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['AccountID'].toString(),
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
                                        item['Name'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        item['LineDescription'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        debit,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        credit,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
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
                                      '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      AppLocalizations.of(context).total,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberFormat(
                                        '#,##0.00',
                                      ).format(_totalDebit),
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
                                      ).format(_totalCredit),
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
}
