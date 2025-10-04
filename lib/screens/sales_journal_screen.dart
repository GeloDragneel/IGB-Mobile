import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class SalesJournalScreen extends StatefulWidget {
  const SalesJournalScreen({super.key});

  @override
  State<SalesJournalScreen> createState() => _SalesJournalScreenState();
}

class _SalesJournalScreenState extends State<SalesJournalScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  List<Map<String, dynamic>> _trialBalanceData = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Journal')),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: Column(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _pickDate(isFrom: true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e2235),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dateFrom != null
                            ? DateFormat("MMM yyyy").format(_dateFrom!)
                            : "Date From",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () => _pickDate(isFrom: false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e2235),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dateTo != null
                            ? DateFormat("MMM yyyy").format(_dateTo!)
                            : "Date To",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_dateFrom == null || _dateTo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select both dates"),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _isLoading = true;
                        });
                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final from = DateFormat('yyyy-MM').format(_dateFrom!);
                        final to = DateFormat('yyyy-MM').format(_dateTo!);
                        final url =
                            'https://igb-fems.com/LIVE/mobile_php/sales_journal.php?userId=${auth.userId}&from=$from&to=$to&branchType=${auth.branchType}&clientNum=${auth.clientNum}';
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
                                totalDebit +=
                                    double.tryParse(item['Debit'].toString()) ??
                                    0;
                                totalCredit +=
                                    double.tryParse(
                                      item['Credit'].toString(),
                                    ) ??
                                    0;
                              }
                              setState(() {
                                _trialBalanceData = invoices;
                                _totalDebit = totalDebit;
                                _totalCredit = totalCredit;

                                _isLoading = false;
                              });
                            } else {
                              setState(() {
                                _isLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${data['result']}'),
                                ),
                              );
                            }
                          } else {
                            setState(() {
                              _isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'HTTP Error: ${response.statusCode}',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          setState(() {
                            _isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8f72ec),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                      ),
                      child: const Text("Generate Report"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trialBalanceData.isEmpty
                ? const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : SingleChildScrollView(
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
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Account ID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Tran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Name',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Line Description',
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
                                'Debit',
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
                                'Credit',
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
                                  double.tryParse(item['Credit'].toString()) ??
                                  0;

                              final debit = debitValue == 0
                                  ? ''
                                  : NumberFormat('#,##0.00').format(debitValue);
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
                                    'Total',
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
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(
                                  0xFF1e2235,
                                ).withValues(alpha: 0.5);
                              }
                              return const Color(0xFF1e2235);
                            },
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
