import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../widgets/scanned_text_dialog.dart';
import '../providers/scan_provider.dart';
import '../providers/auth_provider.dart';

// Model class for expenses record
class ExpenseRecord {
  final String vendorName;
  final String invoiceNo;
  final String documentNo;
  final String date;
  final String declaredMonth;
  final String total;
  final String status;
  final String currency;

  ExpenseRecord({
    required this.vendorName,
    required this.invoiceNo,
    required this.documentNo,
    required this.date,
    required this.declaredMonth,
    required this.total,
    required this.status,
    required this.currency,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      vendorName: json['VendorName'] ?? '',
      currency: json['Currency'] ?? '',
      invoiceNo: json['InvoiceNo'] ?? '',
      documentNo: json['DocumentNo'] ?? '',
      date: json['APDate'] ?? '',
      declaredMonth: json['DeclaredMonth'] ?? '',
      total: json['Total'].toString(),
      status: json['InvoiceStatus'] ?? 'Pending',
    );
  }
}

// Main widget
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final formatter = NumberFormat('#,##0.00');
  Future<List<ExpenseRecord>> _futureExpenseRecords = Future.value([]);
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  List<ExpenseRecord> _allRecords = [];
  List<ExpenseRecord> _filteredRecords = []; // 🔍 filtered list
  File? _image;
  bool _isProcessing = false;
  String _searchQuery = ""; // 🔍 search text

  @override
  void initState() {
    super.initState();
    _futureExpenseRecords = fetchExpenseRecords();
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _isProcessing = true;
      });
      await _performOCR(_image!);
    }
  }

  Future<void> _performOCR(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    String scannedText = recognizedText.text;
    Provider.of<ScanProvider>(
      context,
      listen: false,
    ).setScannedText(scannedText);
    textRecognizer.close();
    setState(() {
      _isProcessing = false;
    });

    // Show popup with scanned text
    if (mounted) {
      ScannedTextDialog.show(context, scannedText, 'Scanned Expense Receipt');
    }
  }

  Future<List<ExpenseRecord>> fetchExpenseRecords() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final response = await http.get(
      Uri.parse(
        'https://igb-fems.com/LIVE/mobile_php/expenses.php?userId=${auth.userId}',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['result'] == 'Success') {
        final List<dynamic> invoices = data['invoices'];
        final records = invoices
            .map((inv) => ExpenseRecord.fromJson(inv))
            .toList();
        _allRecords = records;
        _filteredRecords = records; // initialize filtered list
        return records;
      } else {
        throw Exception('Failed to load expenses records: ${data['result']}');
      }
    } else {
      throw Exception(
        'Failed to load expenses records: ${response.statusCode}',
      );
    }
  }

  void _filterRecords(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords.where((record) {
          return record.vendorName.toLowerCase().contains(_searchQuery) ||
              record.invoiceNo.toLowerCase().contains(_searchQuery) ||
              record.documentNo.toLowerCase().contains(_searchQuery) ||
              record.status.toLowerCase().contains(_searchQuery);
        }).toList();
      }
      _currentPage = 1; // reset to first page after search
    });
  }

  int _getItemsForCurrentPage() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return endIndex > _filteredRecords.length
        ? _filteredRecords.length - startIndex
        : _rowsPerPage;
  }

  int _getTotalPages() {
    return (_filteredRecords.length / _rowsPerPage).ceil();
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final List<Widget> buttons = [];

    buttons.add(
      IconButton(
        onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
        icon: Icon(
          Icons.chevron_left,
          color: _currentPage > 1 ? Colors.white70 : Colors.white30,
        ),
      ),
    );

    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) {
        buttons.add(_buildPageButton(i));
      }
    } else {
      buttons.add(_buildPageButton(1));

      if (_currentPage > 4) {
        buttons.add(_buildEllipsis());
      }

      int start = (_currentPage - 1).clamp(2, totalPages - 2);
      int end = (_currentPage + 1).clamp(3, totalPages - 1);

      for (int i = start; i <= end; i++) {
        if (i != 1 && i != totalPages) {
          buttons.add(_buildPageButton(i));
        }
      }

      if (_currentPage < totalPages - 3) {
        buttons.add(_buildEllipsis());
      }

      if (totalPages > 1) {
        buttons.add(_buildPageButton(totalPages));
      }
    }

    buttons.add(
      IconButton(
        onPressed: _currentPage < totalPages
            ? () => _goToPage(_currentPage + 1)
            : null,
        icon: Icon(
          Icons.chevron_right,
          color: _currentPage < totalPages ? Colors.white70 : Colors.white30,
        ),
      ),
    );

    return buttons;
  }

  Widget _buildPageButton(int page) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _goToPage(page),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _currentPage == page
                ? const Color(0xFF8f72ec)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _currentPage == page
                  ? const Color(0xFF8f72ec)
                  : Colors.white30,
              width: 1,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: _currentPage == page ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        '...',
        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      drawer: AppDrawer(selectedIndex: 3),
      backgroundColor: const Color(0xFF121826),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 🔍 Search bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search expenses...",
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E2235),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: _filterRecords,
            ),
            SizedBox(height: 12),

            ElevatedButton.icon(
              icon: Icon(Icons.qr_code_scanner),
              label: Text('Scan Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8f72ec),
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing ? null : _scanReceipt,
            ),
            if (_isProcessing) ...[
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.white),
            ],
            if (_image != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Image.file(_image!, height: 120),
              ),
            Expanded(
              child: FutureBuilder<List<ExpenseRecord>>(
                  future: _futureExpenseRecords,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No expenses records available'),
                      );
                    } else {
                      final records = _filteredRecords;
                      final itemsOnPage = _getItemsForCurrentPage();
                      final startIndex = (_currentPage - 1) * _rowsPerPage;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Expenses Records',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total: ${records.length} records',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: itemsOnPage,
                              itemBuilder: (context, index) {
                                final record = records[startIndex + index];
                                final isEven = index % 2 == 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isEven
                                        ? const Color(0xFF101222)
                                        : const Color(0xFF0a0f1c),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: record.status == 'Paid'
                                          ? Colors.green.withAlpha(80)
                                          : Colors.orange.withAlpha(80),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                record.vendorName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: record.status == 'Paid'
                                                    ? Colors.green.withAlpha(50)
                                                    : Colors.orange.withAlpha(
                                                        50,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: record.status == 'Paid'
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                record.status,
                                                style: TextStyle(
                                                  color: record.status == 'Paid'
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildInfoItem(
                                                'Document',
                                                record.documentNo,
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildInfoItem(
                                                'Currency',
                                                record.currency,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildInfoItem(
                                                'Date',
                                                record.date,
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildInfoItem(
                                                'Month',
                                                record.declaredMonth,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Total: ${formatter.format(double.tryParse(record.total) ?? 0)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildPageButtons(),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
