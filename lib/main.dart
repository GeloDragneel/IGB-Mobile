import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/scan_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';
import 'screens/sales_screen.dart';
import 'screens/purchases_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/accountingPeriod_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/report_detail_screen.dart';
import 'screens/trial_balance_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/general_ledger_screen.dart';
import 'screens/customer_ledger_screen.dart';
import 'screens/e_bir_screen.dart';
import 'screens/consolidated_report_detailed_screen.dart';
import 'screens/purchase_report_screen.dart';
import 'screens/sales_report_screen.dart';
import 'screens/expense_report_screen.dart';
import 'screens/import_report_screen.dart';
import 'screens/e_sub_report_screen.dart';
import 'screens/bir2307_screen.dart';
import 'screens/income_statement_screen.dart';
import 'screens/annual_summary_screen.dart';
import 'screens/annual_summary_comparative_income_statement_screen.dart';
import 'screens/sales_journal_screen.dart';
import 'screens/purchase_receipts_journal_screen.dart';
import 'screens/cash_disbursement_journal_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/account_payable_screen.dart';
import 'screens/account_receivable_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Scan App',
      theme: ThemeData(
        primaryColor: Color(0xFF0e1726),
        scaffoldBackgroundColor: Color(0xFF060818),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF0e1726),
          foregroundColor: Colors.white,
        ),
        drawerTheme: DrawerThemeData(backgroundColor: Color(0xFF0e1726)),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(Color(0xFF0e1726)),
          dataRowColor: WidgetStateProperty.all(Color(0xFF101222)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isLoggedIn ? Dashboard() : LoginScreen();
          },
        ),
        '/dashboard': (context) => Dashboard(),
        '/sales': (context) => SalesScreen(),
        '/purchases': (context) => PurchasesScreen(),
        '/expenses': (context) => ExpensesScreen(),
        '/profile': (context) => ProfileScreen(),
        '/accountingPeriod': (context) => AccountingPeriodScreen(),
        '/reports': (context) => ReportsScreen(),
        '/report_detail': (context) => ReportDetailScreen(reportName: ModalRoute.of(context)!.settings.arguments as String),
        '/trial_balance': (context) => TrialBalanceScreen(),
        '/summary': (context) => SummaryScreen(),
        '/general_ledger': (context) => GeneralLedgerScreen(),
        '/customer_ledger': (context) => CustomerLedgerScreen(),
        '/e_bir': (context) => EBirScreen(),
        '/consolidated_report_detailed': (context) => ConsolidatedReportDetailedScreen(),
        '/purchase_report': (context) => PurchaseReportScreen(),
        '/sales_report': (context) => SalesReportScreen(),
        '/expense_report': (context) => ExpenseReportScreen(),
        '/import_report': (context) => ImportReportScreen(),
        '/e_sub_report': (context) => ESubReportScreen(),
        '/bir2307': (context) => Bir2307Screen(),
        '/income_statement': (context) => IncomeStatementScreen(),
        '/annual_summary': (context) => AnnualSummaryScreen(),
        '/annual_summary_comparative_income_statement': (context) => AnnualSummaryComparativeIncomeStatementScreen(),
        '/sales_journal': (context) => SalesJournalScreen(),
        '/purchase_receipts_journal': (context) => PurchaseReceiptsJournalScreen(),
        '/cash_disbursement_journal': (context) => CashDisbursementJournalScreen(),
        '/transactions': (context) => TransactionsScreen(),
        '/account_payable': (context) => AccountPayableScreen(),
        '/account_receivable': (context) => AccountReceivableScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
