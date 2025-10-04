import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

class AccountReceivableScreen extends StatefulWidget {
  const AccountReceivableScreen({super.key});

  @override
  State<AccountReceivableScreen> createState() =>
      _AccountReceivableScreenState();
}

class _AccountReceivableScreenState extends State<AccountReceivableScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_dateFrom == null && auth.fromDate.isNotEmpty) {
      _dateFrom = DateTime.tryParse("${auth.fromDate}-01");
    }
    if (_dateTo == null && auth.toDate.isNotEmpty) {
      _dateTo = DateTime.tryParse("${auth.toDate}-01");
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? DateTime.now())
          : (_dateTo ?? DateTime.now()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Receivable')),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    _dateFrom != null
                        ? DateFormat("MMM yyyy").format(_dateFrom!)
                        : "Date From",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

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
                    _dateTo != null
                        ? DateFormat("MMM yyyy").format(_dateTo!)
                        : "Date To",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_dateFrom == null || _dateTo == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select both dates"),
                        ),
                      );
                      return;
                    }
                    final displayFrom = DateFormat(
                      "MMM yyyy",
                    ).format(_dateFrom!);
                    final displayTo = DateFormat("MMM yyyy").format(_dateTo!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Generating Trial Balance from $displayFrom to $displayTo',
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
