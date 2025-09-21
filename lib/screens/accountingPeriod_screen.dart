import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/navigation_drawer.dart';

class AccountingPeriodScreen extends StatefulWidget {
  const AccountingPeriodScreen({super.key});

  @override
  State<AccountingPeriodScreen> createState() => _AccountingPeriodScreenState();
}

class _AccountingPeriodScreenState extends State<AccountingPeriodScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String? _currentSession; // stores created session

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8f72ec),
              onPrimary: Colors.white,
              surface: Color(0xFF1e2235),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _createSession() {
    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select both dates")));
      return;
    }

    final formattedFrom = DateFormat("MMM yyyy").format(_dateFrom!);
    final formattedTo = DateFormat("MMM yyyy").format(_dateTo!);

    setState(() {
      _currentSession = "$formattedFrom → $formattedTo";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Session created: $_currentSession")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounting Period')),
      drawer: AppDrawer(selectedIndex: 2),
      backgroundColor: const Color(0xFF121826),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date From
              GestureDetector(
                onTap: () => _pickDate(isFrom: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e2235),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dateFrom == null
                        ? "Date From"
                        : DateFormat("MMM yyyy").format(_dateFrom!),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              // Date To
              GestureDetector(
                onTap: () => _pickDate(isFrom: false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e2235),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dateTo == null
                        ? "Date To"
                        : DateFormat("MMM yyyy").format(_dateTo!),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              // Create Session button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8f72ec),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text("Create Session"),
                ),
              ),

              const SizedBox(height: 30),

              // Show current session if available
              if (_currentSession != null)
                Column(
                  children: [
                    const Text(
                      "Current Session:",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentSession!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
