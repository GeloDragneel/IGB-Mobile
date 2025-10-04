import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _selectedJournal;
  int? _selectedYear;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedYear == null) {
      _selectedYear = DateTime.now().year;
    }
  }

  Future<void> _pickYear() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        int currentYear = _selectedYear ?? DateTime.now().year;
        return AlertDialog(
          backgroundColor: const Color(0xFF1e2235),
          title: const Text(
            'Select Year',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            height: 200,
            width: 300,
            child: ListView.builder(
              itemCount: 50, // 50 years
              itemBuilder: (context, index) {
                int year = DateTime.now().year - 25 + index;
                return ListTile(
                  title: Text(
                    year.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(year);
                  },
                  selected: year == currentYear,
                  selectedColor: const Color(0xFF8f72ec),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedYear = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedJournal,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1e2235),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                dropdownColor: const Color(0xFF1e2235),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                hint: const Text(
                  'Select Journal',
                  style: TextStyle(color: Colors.white70),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sales Journal',
                    child: Text('Sales Journal'),
                  ),
                  DropdownMenuItem(
                    value: 'Purchase Journal',
                    child: Text('Purchase Journal'),
                  ),
                  DropdownMenuItem(
                    value: 'Expenses Journal',
                    child: Text('Expenses Journal'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedJournal = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: _pickYear,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e2235),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedYear != null
                        ? _selectedYear.toString()
                        : "Select Year",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedJournal == null || _selectedYear == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select journal and year"),
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Generating $_selectedJournal for $_selectedYear',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8f72ec),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text("Generate Report"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
