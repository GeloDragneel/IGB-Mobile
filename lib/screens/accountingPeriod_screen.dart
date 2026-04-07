import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // ✅ Required for Provider
import '../providers/auth_provider.dart'; // ✅ Make sure the path is correct
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

class AccountingPeriodScreen extends StatefulWidget {
  const AccountingPeriodScreen({super.key});

  @override
  State<AccountingPeriodScreen> createState() => _AccountingPeriodScreenState();
}

class _AccountingPeriodScreenState extends State<AccountingPeriodScreen> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String? _currentSession;

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

  void _createSession() {
    if (_dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseSelectBothDates),
        ),
      );
      return;
    }

    final formattedFrom = DateFormat("yyyy-MM").format(_dateFrom!);
    final formattedTo = DateFormat("yyyy-MM").format(_dateTo!);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.fromDate = formattedFrom;
    auth.toDate = formattedTo;

    final displayFrom = DateFormat("MMM yyyy").format(_dateFrom!);
    final displayTo = DateFormat("MMM yyyy").format(_dateTo!);

    setState(() {
      _currentSession = "$displayFrom → $displayTo";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${AppLocalizations.of(context).sessionCreated}: $_currentSession",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).accountPeriod)),
      drawer: AppDrawer(selectedIndex: 2),
      backgroundColor: const Color(0xFF121826),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (auth.fromDate.isNotEmpty && auth.toDate.isNotEmpty)
                Column(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 80, // Big icon size
                      color: const Color(0xFF8f72ec),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).accountingPeriod,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${DateFormat("MMM yyyy").format(DateTime.parse("${auth.fromDate}-01"))} - "
                      "${DateFormat("MMM yyyy").format(DateTime.parse("${auth.toDate}-01"))}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),

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
                        : AppLocalizations.of(context).dateFrom,
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
                        : AppLocalizations.of(context).dateTo,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

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
                  child: Text(AppLocalizations.of(context).createSesion),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
