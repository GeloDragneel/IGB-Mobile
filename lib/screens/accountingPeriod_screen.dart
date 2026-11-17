import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';

/// Same as the web PeriodContext:
///   period = { from: "YYYY-MM-DD", to: "YYYY-MM-DD" }, default = this month,
///   cached under "bizdesk-period" (SharedPreferences = the web's localStorage).
/// auth.fromDate / auth.toDate stay "YYYY-MM" because the rest of the app uses them that way.
class PeriodStore {
  static const key = 'bizdesk-period';
  static final _f = DateFormat('yyyy-MM-dd');

  /// web monthRange(): first and last day of the month (offset = months from today)
  static DateTimeRange monthRange([DateTime? d, int offset = 0]) {
    final base = d ?? DateTime.now();
    final first = DateTime(base.year, base.month + offset, 1);
    return DateTimeRange(
      start: first,
      end: DateTime(first.year, first.month + 1, 0),
    );
  }

  static Future<DateTimeRange> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = jsonDecode(p.getString(key) ?? '{}');
      final from = DateTime.tryParse('${saved['from'] ?? ''}');
      final to = DateTime.tryParse('${saved['to'] ?? ''}');
      if (from != null && to != null)
        return DateTimeRange(start: from, end: to);
    } catch (_) {
      /* nothing saved */
    }
    return monthRange();
  }

  static Future<void> save(DateTimeRange r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      key,
      jsonEncode({'from': _f.format(r.start), 'to': _f.format(r.end)}),
    );
  }

  /// put the cached period into AuthProvider (call after login, before opening the dashboard)
  static Future<DateTimeRange> restore(AuthProvider auth) async {
    final r = await load();
    apply(auth, r);
    return r;
  }

  static void apply(AuthProvider auth, DateTimeRange r) {
    auth.fromDate = DateFormat('yyyy-MM').format(r.start);
    auth.toDate = DateFormat('yyyy-MM').format(r.end);
  }

  /// "Jan 01, 2026 to Dec 31, 2026" (same text as the web sidebar)
  static String label(DateTimeRange r) =>
      '${DateFormat('MMM dd, yyyy').format(r.start)} to ${DateFormat('MMM dd, yyyy').format(r.end)}';
}

/* ---------- palette (same as the web period popover) ---------- */
const _bg = Color(0xFFF4F6FB);
const _panel = Colors.white;
const _box = Color(0xFFF8FAFC);
const _field = Colors.white;
const _border = Color(0xFFE2E8F0);
const _text = Color(0xFF0F172A);
const _label = Color(0xFF64748B);
const _green = Color(0xFF059669);
const _teal = Color(0xFF0D9488);

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class AccountingPeriodScreen extends StatefulWidget {
  const AccountingPeriodScreen({super.key});

  @override
  State<AccountingPeriodScreen> createState() => _AccountingPeriodScreenState();
}

class _AccountingPeriodScreenState extends State<AccountingPeriodScreen> {
  DateTimeRange? _saved; // period in use
  DateTime? _from; // first day of the From month
  DateTime? _to; // first day of the To month

  @override
  void initState() {
    super.initState();
    PeriodStore.load().then((r) {
      if (!mounted) return;
      setState(() {
        _saved = r;
        _from = DateTime(r.start.year, r.start.month);
        _to = DateTime(r.end.year, r.end.month);
      });
    });
  }

  bool get _zh => AppLocalizations.of(context).locale.languageCode == 'zh';
  String _t(String en, String zh) => _zh ? zh : en;

  DateTimeRange get _draft =>
      DateTimeRange(start: _from!, end: DateTime(_to!.year, _to!.month + 1, 0));
  int get _monthCount =>
      (_to!.year - _from!.year) * 12 + _to!.month - _from!.month + 1;
  bool _sameMonths(DateTime f, DateTime t) =>
      f.year == _from!.year &&
      f.month == _from!.month &&
      t.year == _to!.year &&
      t.month == _to!.month;
  bool get _changed =>
      _saved == null ||
      _saved!.start.year != _from!.year ||
      _saved!.start.month != _from!.month ||
      _saved!.end.year != _to!.year ||
      _saved!.end.month != _to!.month;

  /* ---------- quick select: This month · Last month · this quarter · last quarter · this year · last year ---------- */
  List<_Quick> _quick() {
    final n = DateTime.now();
    final q = (n.month - 1) ~/ 3; // 0..3
    final lq = q == 0 ? 3 : q - 1, lqy = q == 0 ? n.year - 1 : n.year;
    return [
      _Quick(
        _t('This month', '本月'),
        DateTime(n.year, n.month),
        DateTime(n.year, n.month),
      ),
      _Quick(
        _t('Last month', '上月'),
        DateTime(n.year, n.month - 1),
        DateTime(n.year, n.month - 1),
      ),
      _Quick(
        'Q${q + 1} ${n.year}',
        DateTime(n.year, q * 3 + 1),
        DateTime(n.year, q * 3 + 3),
      ),
      _Quick(
        'Q${lq + 1} $lqy',
        DateTime(lqy, lq * 3 + 1),
        DateTime(lqy, lq * 3 + 3),
      ),
      _Quick(
        '${_t('Year', '年度')} ${n.year}',
        DateTime(n.year, 1),
        DateTime(n.year, 12),
      ),
      _Quick(
        '${_t('Year', '年度')} ${n.year - 1}',
        DateTime(n.year - 1, 1),
        DateTime(n.year - 1, 12),
      ),
    ];
  }

  Future<void> _pickMonth({required bool from}) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(initial: from ? _from! : _to!),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to!.isBefore(_from!)) _to = _from;
      } else {
        _to = picked;
        if (_to!.isBefore(_from!)) _from = _to;
      }
    });
  }

  Future<void> _apply() async {
    final r = _draft;
    PeriodStore.apply(Provider.of<AuthProvider>(context, listen: false), r);
    await PeriodStore.save(r);
    if (!mounted) return;
    setState(() => _saved = r);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _text,
        content: Text(
          '${_t('Period set', '期间已设置')}: ${PeriodStore.label(r)}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: Text(
          loc.accountPeriod,
          style: const TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawer: AppDrawer(selectedIndex: 2),
      body: _from == null
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
              children: [
                // period in use
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green.withOpacity(.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: _green,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          PeriodStore.label(_saved!),
                          style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // panel (same as the web popover)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _text.withOpacity(.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _caption(_t('QUICK SELECT', '快速选择')),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3.6,
                        children: [for (final q in _quick()) _quickBtn(q)],
                      ),
                      const SizedBox(height: 18),
                      _caption(_t('CUSTOM RANGE', '自定义范围')),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _box,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            _monthRow(
                              _t('From', '从'),
                              _from!,
                              () => _pickMonth(from: true),
                            ),
                            const SizedBox(height: 10),
                            _monthRow(
                              _t('To', '至'),
                              _to!,
                              () => _pickMonth(from: false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$_monthCount ${_monthCount == 1 ? _t('month', '个月') : _t('months', '个月')}',
                              style: const TextStyle(
                                color: _label,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _changed ? _apply : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _teal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFCCFBF1,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF5EAAA8,
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _t('Apply', '应用'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _caption(String t) => Text(
    t,
    style: const TextStyle(
      color: _label,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );

  Widget _quickBtn(_Quick q) {
    final on = _sameMonths(q.from, q.to);
    return InkWell(
      onTap: () => setState(() {
        _from = q.from;
        _to = q.to;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? _green.withOpacity(.10) : _box,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? _green : _border, width: on ? 1.4 : 1),
        ),
        child: Text(
          q.label,
          style: TextStyle(
            color: on ? _green : _text,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _monthRow(String label, DateTime d, VoidCallback onTap) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Text(
          label,
          style: const TextStyle(
            color: _label,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_monthNames[d.month - 1]}  ${d.year}',
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: _label,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Quick {
  _Quick(this.label, DateTime f, DateTime t)
    : from = DateTime(f.year, f.month),
      to = DateTime(t.year, t.month);
  final String label;
  final DateTime from;
  final DateTime to;
}

/// month + year picker in the same dark style
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});
  final DateTime initial;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left_rounded, color: _text),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right_rounded, color: _text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(
                    builder: (_) {
                      final on =
                          _year == widget.initial.year &&
                          m == widget.initial.month;
                      return InkWell(
                        onTap: () => Navigator.pop(context, DateTime(_year, m)),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? _green.withOpacity(.10) : _box,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: on ? _green : _border),
                          ),
                          child: Text(
                            _monthNames[m - 1].substring(0, 3),
                            style: TextStyle(
                              color: on ? _green : _text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
