import 'package:flutter/material.dart';
import '../widgets/navigation_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      drawer: AppDrawer(selectedIndex: 0),
      body: Center(
        child: Text(
          'Welcome to the Home Page!',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
