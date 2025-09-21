import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                child: const Text('Dashboard'),
                onPressed: () => Navigator.pushNamed(context, '/dashboard'),
              ),
              ElevatedButton(
                child: const Text('Profile'),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
              ElevatedButton(
                child: const Text('Scan'),
                onPressed: () => Navigator.pushNamed(context, '/scan'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
                onPressed: () {
                  appProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
