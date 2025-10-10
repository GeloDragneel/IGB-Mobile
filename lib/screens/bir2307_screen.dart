import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class Bir2307Screen extends StatefulWidget {
  const Bir2307Screen({super.key});

  @override
  State<Bir2307Screen> createState() => _Bir2307ScreenState();
}

class _Bir2307ScreenState extends State<Bir2307Screen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedReportType;
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  List<Map<String, dynamic>> _header = [];
  Map<String, dynamic> _footer = {};

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

  final List<Map<String, String>> _reportTypes = [
    {'value': 'BIR2307_S_VT', 'display': 'Summary of Sales BIR2307 (VT/PT)'},
    {'value': 'BIR2307_S_IT', 'display': 'Summary of Sales BIR2307 (IT)'},
    {
      'value': 'BIR2307_PE_IT',
      'display': 'Summary of Purchases and Expenses (IT)',
    },
  ];

  Future<void> _generateReport() async {
    if (_dateFrom == null || _dateTo == null || _selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select report type and both dates"),
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final fromStr = DateFormat('yyyy-MM').format(_dateFrom!);
    final toStr = DateFormat('yyyy-MM').format(_dateTo!);

    // Note: You need to pass the actual clientNum value here
    final url =
        'https://igb-fems.com/LIVE/mobile_php/bir2307.php?userId=${auth.userId}&from=$fromStr&to=$toStr&reportType=$_selectedReportType&branchType=${auth.branchType}&clientNum=${auth.clientNum}';

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] == 'Success') {
          final invoices = data['invoices'];
          setState(() {
            _reportData = List<Map<String, dynamic>>.from(invoices['data']);
            _header = List<Map<String, dynamic>>.from(invoices['header']);
            _footer = Map<String, dynamic>.from(invoices['footer']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${data['result']}')));
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed to generate report: ${response.statusCode}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildReportTable() {
    if (_reportData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2235),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            const Color(0xFF8f72ec).withOpacity(0.2),
          ),
          dataRowColor: MaterialStateProperty.all(const Color(0xFF1e2235)),
          columns: [
            const DataColumn(
              label: Text(
                'ATC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._header.map((month) {
              return DataColumn(
                label: Text(
                  month['formatted'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
            const DataColumn(
              label: Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: [
            ..._reportData.map((row) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      row['atc_display'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ...List.generate(_header.length, (index) {
                    final monthData = row['months'][index];
                    return DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberFormat(
                              '#,##0.00',
                            ).format(monthData['tax_base']),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            NumberFormat(
                              '#,##0.00',
                            ).format(monthData['bir2307']),
                            style: const TextStyle(
                              color: Color(0xFF8f72ec),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat('#,##0.00').format(row['total_amount']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          NumberFormat('#,##0.00').format(row['total_bir2307']),
                          style: const TextStyle(
                            color: Color(0xFF8f72ec),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
            // Footer row
            DataRow(
              color: MaterialStateProperty.all(
                const Color(0xFF8f72ec).withOpacity(0.3),
              ),
              cells: [
                const DataCell(
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...(_footer['months'] as List? ?? []).map<DataCell>((month) {
                  return DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat('#,##0.00').format(month['tax_base']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          NumberFormat('#,##0.00').format(month['bir2307']),
                          style: const TextStyle(
                            color: Color(0xFF8f72ec),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat(
                          '#,##0.00',
                        ).format(_footer['grand_total_tax_base'] ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        NumberFormat(
                          '#,##0.00',
                        ).format(_footer['grand_total_bir2307'] ?? 0),
                        style: const TextStyle(
                          color: Color(0xFF8f72ec),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BIR2307')),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2235),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedReportType,
                  dropdownColor: const Color(0xFF1e2235),
                  style: const TextStyle(color: Colors.white),
                  hint: const Text(
                    'Select Report Type',
                    style: TextStyle(color: Colors.white70),
                  ),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _reportTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(
                        type['display']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReportType = value;
                    });
                  },
                ),
              ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _generateReport,
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
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF8f72ec),
                      ),
                    )
                  : _buildReportTable(),
            ],
          ),
        ),
      ),
    );
  }
}
