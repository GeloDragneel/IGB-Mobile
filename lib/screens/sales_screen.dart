import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';
import 'sales_scan_dialog.dart';

// Model class for purchase record
class SalesRecord {
  final String fileName;
  final String status;
  final String dateAdded;
  final String reference;
  final int id;

  SalesRecord({
    required this.fileName,
    required this.status,
    required this.dateAdded,
    required this.reference,
    required this.id,
  });

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    return SalesRecord(
      fileName: json['Filename'] ?? '',
      status: json['Status'] ?? '',
      dateAdded: json['DateAdded'] ?? '',
      reference: json['Reference'] ?? '',
      id: json['ID'] ?? '',
    );
  }
}

// Main widget
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final formatter = NumberFormat('#,##0.00');
  Future<List<SalesRecord>> _futureSalesRecords = Future.value([]);
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  List<SalesRecord> _allRecords = [];
  List<SalesRecord> _filteredRecords = []; // 🔍 filtered list
  String _searchQuery = ""; // 🔍 search text

  @override
  void initState() {
    super.initState();
    _futureSalesRecords = fetchSalesRecords();
  }

  Future<List<SalesRecord>> fetchSalesRecords() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final response = await http.get(
      Uri.parse(
        'https://igb-fems.com/LIVE/mobile_php/sales.php?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['result'] == 'Success') {
        final List<dynamic> invoices = data['invoices'];
        final records = invoices
            .map((inv) => SalesRecord.fromJson(inv))
            .toList();
        _allRecords = records;
        _filteredRecords = records; // initialize filtered list
        return records;
      } else {
        throw Exception('Failed to load sales records: ${data['result']}');
      }
    } else {
      throw Exception('Failed to load sales records: ${response.statusCode}');
    }
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SalesScanDialog(
          onUploadSuccess: () {
            setState(() {
              _futureSalesRecords = fetchSalesRecords();
            });
          },
        );
      },
    );
  }

  void _filterRecords(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords.where((record) {
          return record.fileName.toLowerCase().contains(_searchQuery);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales / Invoices',
          style: TextStyle(
            fontSize: 18, // smaller font size, default is around 20-22
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showScanDialog,
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 26, // bigger icon size (default is 24)
            ),
            label: const Text(
              'Scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18, // bigger text size
              ),
            ),
          ),
        ],
      ),

      drawer: AppDrawer(selectedIndex: 3),
      backgroundColor: const Color(0xFF121826),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 🔍 Search bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search sales...",
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

            Expanded(
              child: FutureBuilder<List<SalesRecord>>(
                future: _futureSalesRecords,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No sales records available'),
                    );
                  } else {
                    final records = _filteredRecords;
                    final itemsOnPage = _getItemsForCurrentPage();
                    final startIndex = (_currentPage - 1) * _rowsPerPage;

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            itemCount: itemsOnPage,
                            itemBuilder: (context, index) {
                              final record = records[startIndex + index];

                              // Parse and format the date
                              DateTime? parsedDate;
                              try {
                                parsedDate = DateFormat(
                                  'yyyy-MM-dd',
                                ).parse(record.dateAdded);
                              } catch (_) {}

                              String timeAgo = parsedDate != null
                                  ? '${DateTime.now().difference(parsedDate).inDays} days ago'
                                  : record.dateAdded;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1D2E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  leading: Icon(
                                    Icons.picture_as_pdf,
                                    color: (record.status == 'Pending'
                                        ? Colors.redAccent
                                        : Colors.greenAccent),
                                    size: 40,
                                  ),

                                  title: Text(
                                    record.fileName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$timeAgo • ',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ), // default white color for $timeAgo and separator
                                        ),
                                        TextSpan(
                                          text: record.status,
                                          style: TextStyle(
                                            color: record.status == 'Pending'
                                                ? Colors.redAccent
                                                : Colors.greenAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'view') {
                                        final auth = Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ViewScreen(
                                              invoiceNo: record.reference,
                                              userId: auth.userId,
                                            ),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(
                                              0xFF1E2235,
                                            ),
                                            title: const Text(
                                              'Confirm Delete',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            content: const Text(
                                              'Are you sure you want to delete this item?',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  ctx,
                                                ).pop(false),
                                                child: const Text(
                                                  'No',
                                                  style: TextStyle(
                                                    color: Color(0xFF8f72ec),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text(
                                                  'Yes',
                                                  style: TextStyle(
                                                    color: Color(0xFF8f72ec),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true) {
                                          print('Delete confirmed');

                                          try {
                                            // Replace `record.id` with the actual ID from your record
                                            final deleteUrl = Uri.parse(
                                              'https://igb-fems.com/LIVE/mobile_php/delete_transaction.php?id=${record.id}',
                                            );
                                            final response = await http.get(
                                              deleteUrl,
                                            );

                                            if (response.statusCode == 200) {
                                              final responseBody =
                                                  response.body;
                                              print(
                                                'Delete response: $responseBody',
                                              );

                                              // Optionally parse JSON and show snackbar or update UI accordingly
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Item deleted successfully.',
                                                  ),
                                                ),
                                              );
                                              // Reload your list after delete
                                              setState(() {
                                                _futureSalesRecords =
                                                    fetchSalesRecords();
                                              });
                                              // Refresh your list or update state here after deletion
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to delete item.',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error deleting item: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        } else {
                                          print('Delete canceled');
                                        }
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      if (record.status == 'Confirmed') {
                                        return [
                                          const PopupMenuItem<String>(
                                            value: 'view',
                                            child: Text('View'),
                                          ),
                                        ];
                                      } else if (record.status == 'Pending') {
                                        return [
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ];
                                      } else {
                                        return [];
                                      }
                                    },
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

class ViewScreen extends StatefulWidget {
  final String invoiceNo;
  final String userId;

  const ViewScreen({super.key, required this.invoiceNo, required this.userId});

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  final formatter = NumberFormat('#,##0.00');
  Map<String, dynamic>? invoiceData;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchInvoice();
  }

  Future<void> fetchInvoice() async {
    final url =
        'https://igb-fems.com/LIVE/mobile_php/sales_info.php?InvoiceNo=${widget.invoiceNo}&UserID=${widget.userId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success' &&
            data['invoices'] is List &&
            (data['invoices'] as List).isNotEmpty) {
          setState(() {
            invoiceData = data['invoices'][0];
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'No invoice data found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'HTTP ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales / Invoices'),
        backgroundColor: const Color(0xFF121826),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF121826),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $error',
                style: TextStyle(color: Colors.white),
              ),
            )
          : invoiceData == null
          ? const Center(
              child: Text('No data', style: TextStyle(color: Colors.white)),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Card(
                  color: const Color(0xFF1E2235),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'RECEIPT',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          thickness: 2,
                          color: Colors.white10,
                          height: 30,
                        ),
                        // Invoice Info
                        Container(
                          padding: EdgeInsets.all(12),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Document #: ${invoiceData!['DocumentNo']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Client: ${invoiceData!['ClientName']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Date: ${invoiceData!['TransactionDate']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Status: ${invoiceData!['InvoiceStatus']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'TIN: ${invoiceData!['TIN']}',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Items Header
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8f72ec).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Price',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: Colors.transparent, height: 20),
                        // Items
                        ...(invoiceData!['detail'] as List<dynamic>).map(
                          (item) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121826),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['Description'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    item['Qty'],
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    formatter.format(
                                      item['Price'] is String
                                          ? double.parse(item['Price'])
                                          : item['Price'],
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    formatter.format(
                                      item['Total'] is String
                                          ? double.parse(item['Total'])
                                          : item['Total'],
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          thickness: 1,
                          color: Colors.transparent,
                          height: 10,
                        ),
                        // Totals
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8f72ec).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8f72ec),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Subtotal: ${formatter.format(invoiceData!['SubTotal'] is String ? double.parse(invoiceData!['SubTotal']) : invoiceData!['SubTotal'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Discount: ${formatter.format(invoiceData!['DiscountAmount'] is String ? double.parse(invoiceData!['DiscountAmount']) : invoiceData!['DiscountAmount'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Income Tax: ${formatter.format(invoiceData!['2307_IT'] is String ? double.parse(invoiceData!['2307_IT']) : invoiceData!['2307_IT'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Grand Total: ${formatter.format(invoiceData!['Total'] is String ? double.parse(invoiceData!['Total']) : invoiceData!['Total'])}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8f72ec),
                                    ),
                                  ),
                                ],
                              ),
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
}
