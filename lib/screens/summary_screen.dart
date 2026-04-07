import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
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

  // ─── Date picker tile ────────────────────────────────────────────────────────
  Widget _datePickerTile({required bool isFrom, bool compact = false}) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 10 : 14,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1e2235),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFrom
              ? (_dateFrom != null
                    ? DateFormat("MMM yyyy").format(_dateFrom!)
                    : AppLocalizations.of(context).dateFrom)
              : (_dateTo != null
                    ? DateFormat("MMM yyyy").format(_dateTo!)
                    : AppLocalizations.of(context).dateTo),
          style: TextStyle(color: Colors.white, fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  // ─── Shared button style ─────────────────────────────────────────────────────
  ButtonStyle _buttonStyle({bool compact = false}) => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF8f72ec),
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14, horizontal: 24),
  );

  // ─── Generate button ─────────────────────────────────────────────────────────
  Widget _generateButton({bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 42 : null,
      child: ElevatedButton(
        onPressed: () {
          if (_dateFrom == null || _dateTo == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).pleaseSelectBothDates,
                ),
              ),
            );
            return;
          }
          final displayFrom = DateFormat("MMM yyyy").format(_dateFrom!);
          final displayTo = DateFormat("MMM yyyy").format(_dateTo!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context).generatingSummaryFrom} $displayFrom ${AppLocalizations.of(context).to} $displayTo',
              ),
            ),
          );
        },
        style: _buttonStyle(compact: compact),
        child: Text(
          AppLocalizations.of(context).generateReport,
          style: TextStyle(fontSize: compact ? 14 : 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Detect orientation ────────────────────────────────────────────────────
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).summary)),
      drawer: AppDrawer(selectedIndex: 6),
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isLandscape ? 8 : 20,
          ),
          child: isLandscape
              // ── LANDSCAPE ─────────────────────────────────────────────────
              ? Row(
                  children: [
                    Expanded(
                      child: _datePickerTile(isFrom: true, compact: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _datePickerTile(isFrom: false, compact: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _generateButton(compact: true)),
                  ],
                )
              // ── PORTRAIT ──────────────────────────────────────────────────
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _datePickerTile(isFrom: true),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: _datePickerTile(isFrom: false),
                    ),
                    _generateButton(),
                  ],
                ),
        ),
      ),
    );
  }
}
