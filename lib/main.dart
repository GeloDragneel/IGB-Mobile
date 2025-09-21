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
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
