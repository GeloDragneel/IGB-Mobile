import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class EBirScreen extends StatefulWidget {
  const EBirScreen({super.key});

  @override
  State<EBirScreen> createState() => _EBirScreenState();
}

class _EBirScreenState extends State<EBirScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  List<Map<String, dynamic>> _invoices = [];

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

  Future<void> _fetchEBirData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final from = DateFormat('yyyy-MM').format(_dateFrom!);
    final to = DateFormat('yyyy-MM').format(_dateTo!);
    final url =
        'https://igb-fems.com/LIVE/mobile_php/e_bir.php?userId=${auth.userId}&from=$from&to=$to&branchType=${auth.branchType}&clientNum=${auth.clientNum}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          setState(() {
            _invoices = List<Map<String, dynamic>>.from(data['invoices']);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${data['result']}')));
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to fetch data')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-BIR')),
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
                      onPressed: () {
                        if (_dateFrom == null || _dateTo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select both dates"),
                            ),
                          );
                          return;
                        }
                        _fetchEBirData();
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
                : _invoices.isEmpty
                ? const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : _buildTable(),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (_invoices.isEmpty) return [];
    final header = _invoices[0];
    final numColumns = header.keys.where((k) => k.startsWith('column_')).length;
    return List.generate(numColumns, (i) {
      final key = 'column_${i + 1}';
      return DataColumn(
        label: Text(
          header[key] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    });
  }

  List<DataRow> _buildRows() {
    if (_invoices.length <= 1) return [];
    final numColumns = _invoices[0].keys
        .where((k) => k.startsWith('column_'))
        .length;
    return _invoices.skip(1).map((invoice) {
      return DataRow(
        cells: List.generate(numColumns, (i) {
          final key = 'column_${i + 1}';
          return DataCell(
            Text(
              invoice[key] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }),
      );
    }).toList();
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: DataTable(
            border: TableBorder.all(color: Colors.grey.shade600, width: 1),
            columnSpacing: 15,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 30,
            headingRowHeight: 30,
            columns: _buildColumns(),
            rows: _buildRows(),
            headingRowColor: WidgetStateProperty.all(const Color(0xFF8f72ec)),
            dataRowColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF1e2235).withValues(alpha: 0.5);
              }
              return const Color(0xFF1e2235);
            }),
          ),
        ),
      ),
    );
  }
}
