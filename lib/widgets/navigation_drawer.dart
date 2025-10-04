import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  const AppDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(auth.tradeName),
            accountEmail: Text(auth.fullName),
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            decoration: BoxDecoration(color: Color(0xFF0e1726)),
          ),
          ListTile(
            leading: Icon(Icons.home, color: Colors.white),
            title: Text('Dashboard', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 0,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.attach_money, color: Colors.white),
            title: Text('Sales', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 3,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/sales');
            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart, color: Colors.white),
            title: Text('Purchases', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 4,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/purchases');
            },
          ),
          ListTile(
            leading: Icon(Icons.receipt, color: Colors.white),
            title: Text('Expenses', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 5,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/expenses');
            },
          ),
          ListTile(
            leading: Icon(Icons.report, color: Colors.white),
            title: Text('Reports', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 6,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/reports');
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text('Profile', style: TextStyle(color: Colors.white)),
            selected: selectedIndex == 1,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.calendar_month, color: Colors.white),
            title: Text(
              'Accounting Period',
              style: TextStyle(color: Colors.white),
            ),
            selected: selectedIndex == 2,
            selectedTileColor: Color(0xFF101222),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/accountingPeriod');
            },
          ),
          Spacer(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.white),
            title: Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () {
              auth.logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }
}
