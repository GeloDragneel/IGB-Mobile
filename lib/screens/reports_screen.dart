import 'package:flutter/material.dart';
import '../widgets/navigation_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _reportsConst = [
    'Trial Balance',
    'Summary',
    'General Ledger',
    'Customer Ledger',
    'E-BIR',
    'Consolidated Report (Detailed)',
    'Purchase Report',
    'Sales Report',
    'Expense Report',
    'Import Report',
    'E-Sub Report',
    'BIR2307',
    'Income Statement',
    'Annual Summary',
    'Annual Summary - Comparative Income Statement',
    'Sales Journal',
    'Purchase Receipts Journal',
    'Cash Disbursement Journal',
    'Transactions',
    'Account Payable',
    'Account Receivable',
  ];

  static const Map<String, String> _reportRoutes = {
    'Trial Balance': '/trial_balance',
    'Summary': '/summary',
    'General Ledger': '/general_ledger',
    'Customer Ledger': '/customer_ledger',
    'E-BIR': '/e_bir',
    'Consolidated Report (Detailed)': '/consolidated_report_detailed',
    'Purchase Report': '/purchase_report',
    'Sales Report': '/sales_report',
    'Expense Report': '/expense_report',
    'Import Report': '/import_report',
    'E-Sub Report': '/e_sub_report',
    'BIR2307': '/bir2307',
    'Income Statement': '/income_statement',
    'Annual Summary': '/annual_summary',
    'Annual Summary - Comparative Income Statement': '/annual_summary_comparative_income_statement',
    'Sales Journal': '/sales_journal',
    'Purchase Receipts Journal': '/purchase_receipts_journal',
    'Cash Disbursement Journal': '/cash_disbursement_journal',
    'Transactions': '/transactions',
    'Account Payable': '/account_payable',
    'Account Receivable': '/account_receivable',
  };

  List<String> _filteredReports = [];

  @override
  void initState() {
    super.initState();
    _filteredReports = List.from(_reportsConst)..sort();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReports =
          _reportsConst
              .where((report) => report.toLowerCase().contains(query))
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredReports.length,
                itemBuilder: (context, index) {
                  final report = _filteredReports[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildReportCard(context, report),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search reports...',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white),
        filled: true,
        fillColor: const Color(0xFF1F2937),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String reportName) {
    return Card(
      color: const Color(0xFF101222),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, _reportRoutes[reportName]!);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.description, size: 24, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  reportName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
