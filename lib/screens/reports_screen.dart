import 'package:flutter/material.dart';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';
import '../widgets/chat_bubble.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ✅ English keys used for routing only
  static const List<String> _reportKeys = [
    'trial_balance',
    'summary',
    'general_ledger',
    'customer_ledger',
    'e_bir',
    'consolidated_report_detailed',
    'purchase_report',
    'sales_report',
    'expense_report',
    'import_report',
    'e_sub_report',
    'bir2307',
    'income_statement',
    'annual_summary',
    'annual_summary_comparative',
    'sales_journal',
    'purchase_receipts_journal',
    'cash_disbursement_journal',
    'transactions',
    'account_payable',
    'account_receivable',
  ];

  static const Map<String, String> _reportRoutes = {
    'trial_balance': '/trial_balance',
    'summary': '/summary',
    'general_ledger': '/general_ledger',
    'customer_ledger': '/customer_ledger',
    'e_bir': '/e_bir',
    'consolidated_report_detailed': '/consolidated_report_detailed',
    'purchase_report': '/purchase_report',
    'sales_report': '/sales_report',
    'expense_report': '/expense_report',
    'import_report': '/import_report',
    'e_sub_report': '/e_sub_report',
    'bir2307': '/bir2307',
    'income_statement': '/income_statement',
    'annual_summary': '/annual_summary',
    'annual_summary_comparative':
        '/annual_summary_comparative_income_statement',
    'sales_journal': '/sales_journal',
    'purchase_receipts_journal': '/purchase_receipts_journal',
    'cash_disbursement_journal': '/cash_disbursement_journal',
    'transactions': '/transactions',
    'account_payable': '/account_payable',
    'account_receivable': '/account_receivable',
  };

  List<String> _filteredKeys = [];

  @override
  void initState() {
    super.initState();
    _filteredKeys = List.from(_reportKeys);
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
    final loc = AppLocalizations.of(context);
    setState(() {
      _filteredKeys = _reportKeys.where((key) {
        final translated = loc.translate(key).toLowerCase();
        return translated.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).reports)),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: Stack(
        // 👈 Wrap with Stack
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredKeys.length,
                    itemBuilder: (context, index) {
                      final key = _filteredKeys[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildReportCard(context, key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const ChatBubble(), // 👈 Add ChatBubble here
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).searchReport,
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

  Widget _buildReportCard(BuildContext context, String key) {
    final loc = AppLocalizations.of(context);
    return Card(
      color: const Color(0xFF101222),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, _reportRoutes[key]!);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.description, size: 24, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  loc.translate(key), // ✅ shows translated name
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
