import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: AppDrawer(selectedIndex: 1),
      backgroundColor: const Color(0xFF121826),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              auth.tradeName,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            Text(
              auth.fullName,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            Text(
              auth.branchCode,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
