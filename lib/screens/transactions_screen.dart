import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

const Map<String, String> headerToFooterKey = {
  'Amount': 'F_Total',
  'PHP Amount': 'F_PHPAmount',
  'VAT Exempt': 'F_VATExempt',
  'Zero Rated': 'F_ZeroRated',
  'Non VAT': 'F_NonVAT',
  'Net of VAT': 'F_NetOfVAT',
  'input VAT': 'F_inputVAT',
  'BIR2307(VT/PT)': 'F2307_VT',
  'BIR2307(IT)': 'F2307_IT',
};

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _selectedJournal;
  int? _selectedYear;
  List<Map<String, dynamic>> transactions = [];
  List<String> headers = [];
  Map<String, dynamic> footer = {};
  bool isLoading = false;
  String? error;
  final TransformationController _transformationController =
      TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedYear == null) {
      _selectedYear = DateTime.now().year;
    }
  }

  String _getDisplayValue(Map<String, dynamic> item, String header) {
    switch (header) {
      case 'Transaction ID':
        return item['TransactionID'].toString();
      case 'Date':
        return item['TransactionDate'].toString();
      case 'Vendor/Customer':
        return item['VendorCustomer']['name'].toString();
      case 'TIN':
        return item['TIN'].toString();
      case 'Branch Code':
        return item['BranchCode'].toString();
      case 'Tax Type':
        return item['TaxType'].toString();
      case 'Street and Barangay':
        return item['StreetBarangay'].toString();
      case 'City/Municipality/Province/Country':
        return item['CityCountry'].toString();
      case 'Document':
        return item['DocumentNo'].toString();
      case 'Remarks':
        return item['Remarks'].toString();
      case 'Client Branch':
        return item['ClientBranch'].toString();
      case 'Declared Month':
        return item['DeclaredMonth'].toString();
      case 'Tax Declared For':
        return (item['TaxDeclaredFor'] as List).join(', ');
      case 'Account Title':
        return (item['AccountTitle'] as List).map((e) => e['name']).join(', ');
      case 'Currency':
        return item['Currency'].toString();
      case 'Amount':
        return item['Amount'][0]['formatted'];
      case 'Exchange Rate':
        return item['ExchangeRate'].toString();
      case 'PHP Amount':
        return item['PHPAmount'][0]['formatted'];
      case 'VAT Exempt':
        return item['VATExempt'][0]['formatted'];
      case 'Zero Rated':
        return item['ZeroRated'][0]['formatted'];
      case 'Non VAT':
        return item['NonVAT'][0]['formatted'];
      case 'Net of VAT':
        return item['NetOfVAT'][0]['formatted'];
      case 'input VAT':
        return item['inputVAT'][0]['formatted'];
      case 'ATC(VT/PT)':
        return item['ATC_VT'].toString();
      case 'BIR2307(VT/PT)':
        return item['BIR2307_VT']['formatted'];
      case '2307 (VT/PT) Declared Month':
        return item['VT_DeclaredMonth'].toString();
      case 'BIR2307(VT/PT) Remarks':
        return item['VT_DeclaredRemarks'].toString();
      case 'ATC(IT)':
        return item['ATC_IT'].toString();
      case 'BIR2307(IT)':
        return item['BIR2307_IT']['formatted'];
      case '2307 (IT) Declared Month':
        return item['IT_DeclaredMonth'].toString();
      case 'BIR2307(IT) Remarks':
        return item['IT_DeclaredRemarks'].toString();
      case 'Status':
        return item['Status'].toString();
      case 'Entry By':
        return item['EntryBy'].toString();
      case 'DateTime Entry':
        return item['DateTimeEntry'].toString();
      default:
        return '';
    }
  }

  String _getFooterValue(String header) {
    if (header == 'Transaction ID') return 'Total';
    String? key = headerToFooterKey[header];
    if (key != null && footer.containsKey(key)) {
      var val = footer[key];
      if (val is Map && val.containsKey('formatted')) return val['formatted'];
      if (val is num) return NumberFormat('#,##0.00').format(val);
      return val.toString();
    }
    return '';
  }

  // ─── Shared button style ───────────────────────────────────────────────────
  ButtonStyle _buttonStyle({bool compact = false}) => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF8f72ec),
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14, horizontal: 24),
  );

  // ─── Generate button ───────────────────────────────────────────────────────
  Widget _generateButton({bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 42 : null,
      child: ElevatedButton(
        onPressed: () async {
          if (_selectedJournal == null || _selectedYear == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).pleaseSelectJournalAndYear,
                ),
              ),
            );
            return;
          }
          setState(() {
            isLoading = true;
            error = null;
            transactions = [];
            headers = [];
            footer = {};
          });
          try {
            String transactionType = _selectedJournal!.replaceAll(' ', '');
            String url =
                'https://igb-fems.com/LIVE/mobile_php/transaction.php?userId=10&transactionType=$transactionType&year=$_selectedYear';
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['result'] == 'Success') {
                setState(() {
                  headers = List<String>.from(json['header']);
                  transactions = List<Map<String, dynamic>>.from(
                    json['data'].map((e) => Map<String, dynamic>.from(e)),
                  );
                  footer = Map<String, dynamic>.from(json['footer']);
                  isLoading = false;
                });
              } else {
                setState(() {
                  error = 'Failed to load data';
                  isLoading = false;
                });
              }
            } else {
              setState(() {
                error = 'HTTP error: ${response.statusCode}';
                isLoading = false;
              });
            }
          } catch (e) {
            setState(() {
              error = e.toString();
              isLoading = false;
            });
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

  Future<void> _pickYear() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int currentYear = _selectedYear ?? DateTime.now().year;
        return AlertDialog(
          backgroundColor: const Color(0xFF1e2235),
          title: Text(
            AppLocalizations.of(context).selectYear,
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            height: 200,
            width: 300,
            child: ListView.builder(
              itemCount: 50,
              itemBuilder: (context, index) {
                int year = DateTime.now().year - 25 + index;
                return ListTile(
                  title: Text(
                    year.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(year);
                  },
                  selected: year == currentYear,
                  selectedColor: const Color(0xFF8f72ec),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedYear = picked;
      });
    }
  }

  // ─── Year picker tile ──────────────────────────────────────────────────────
  Widget _yearPickerTile({bool compact = false}) {
    return GestureDetector(
      onTap: _pickYear,
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
          _selectedYear != null
              ? _selectedYear.toString()
              : AppLocalizations.of(context).selectYear,
          style: TextStyle(color: Colors.white, fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).transactions),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
          ),
        ],
      ),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: Column(
        children: [
          // ── Filter section ────────────────────────────────────────────────
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isLandscape ? 8 : 20,
              ),
              child: isLandscape
                  // ── LANDSCAPE ───────────────────────────────────────────
                  ? Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedJournal,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1e2235),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                            ),
                            dropdownColor: const Color(0xFF1e2235),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            hint: Text(
                              AppLocalizations.of(context).selectJournal,
                              style: TextStyle(color: Colors.white70),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'Sales Journal',
                                child: Text(
                                  AppLocalizations.of(context).salesJournal,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Purchase Journal',
                                child: Text(
                                  AppLocalizations.of(context).purchaseJournal,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Expenses Journal',
                                child: Text(
                                  AppLocalizations.of(context).expensesJournal,
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedJournal = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _yearPickerTile(compact: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _generateButton(compact: true)),
                      ],
                    )
                  // ── PORTRAIT ─────────────────────────────────────────────
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedJournal,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1e2235),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                          ),
                          dropdownColor: const Color(0xFF1e2235),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          hint: Text(
                            AppLocalizations.of(context).selectJournal,
                            style: TextStyle(color: Colors.white70),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Sales Journal',
                              child: Text(
                                AppLocalizations.of(context).salesJournal,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Purchase Journal',
                              child: Text(
                                AppLocalizations.of(context).purchaseJournal,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Expenses Journal',
                              child: Text(
                                AppLocalizations.of(context).expensesJournal,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedJournal = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: _yearPickerTile(),
                        ),
                        _generateButton(),
                      ],
                    ),
            ),
          ),
          // ── Table section ─────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : transactions.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).noRecordFound,
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    transformationController: _transformationController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: DataTable(
                            border: TableBorder.all(
                              color: Colors.grey.shade600,
                              width: 1,
                            ),
                            columnSpacing: 15,
                            dataRowMinHeight: 30,
                            dataRowMaxHeight: 30,
                            headingRowHeight: 30,
                            columns: headers
                                .map(
                                  (header) => DataColumn(
                                    label: Text(
                                      header,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            rows: [
                              ...transactions.map(
                                (item) => DataRow(
                                  cells: headers
                                      .map(
                                        (header) => DataCell(
                                          Text(
                                            _getDisplayValue(item, header),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              DataRow(
                                cells: headers
                                    .map(
                                      (header) => DataCell(
                                        Text(
                                          _getFooterValue(header),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
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
