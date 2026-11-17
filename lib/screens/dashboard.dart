import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/navigation_drawer.dart';
import 'accountingPeriod_screen.dart';

/// Same look as the web Home: gradient hero with "Next BIR deadline", gradient KPI tiles
/// with count-up numbers + sparklines, tax payables, Sales vs costs chart, cost ring, BIR calendar.
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

/* ---------- web palette ---------- */
const _page = Color(0xFFF4F6FB);
const _card = Colors.white;
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _line = Color(0xFFE2E8F0);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFF97316);

const _gSales = [Color(0xFF6366F1), Color(0xFF8B5CF6)];
const _gCosts = [Color(0xFFF97316), Color(0xFFEC4899)];
const _gCust = [Color(0xFF10B981), Color(0xFF06B6D4)];
const _gVend = [Color(0xFFEC4899), Color(0xFFF43F5E)];
const _gVat = [Color(0xFF7C3AED), Color(0xFFA855F7)];
const _gEwt = [Color(0xFFEA580C), Color(0xFFF59E0B)];
const _gInc = [Color(0xFF0EA5E9), Color(0xFF2563EB)];
const _gComp = [Color(0xFF059669), Color(0xFF14B8A6)];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic> data = {};
  bool isLoading = true;
  bool failed = false;
  bool _vat = true;
  bool _corp = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    fetchData();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _vat = p.getBool('home.vat') ?? true;
      _corp = p.getBool('home.corp') ?? true;
    });
  }

  Future<void> _savePref(String k, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(k, v);

  Future<void> fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await PeriodStore.restore(
      auth,
    ); // cached Accounting Period, same as the web
    final url =
        '${ApiConstants.baseUrl}/dashboard?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}';
    try {
      final res = await http.get(Uri.parse(url));
      if (!mounted) return;
      setState(() {
        if (res.statusCode == 200) {
          data = json.decode(res.body);
          failed = false;
        } else {
          failed = true;
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('DASHBOARD ERROR: $e');
      if (mounted)
        setState(() {
          isLoading = false;
          failed = true;
        });
    }
  }

  /* ---------- helpers ---------- */
  double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
  Map<String, dynamic> _m(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List _l(dynamic v) => v is List ? v : const [];

  // web shape: { sales:{total,count,vat}, buy:{purchases,expenses,count,vat}, trend:[{label,sales,costs}],
  //              top_customers, recent, attention, payables:{ar,ap,vat,ewt,comp}, income_tax }
  bool get _web => data['sales'] is Map;
  double get _salesTotal =>
      _web ? _d(_m(data['sales'])['total']) : _d(data['totalSales']);
  int get _salesCount => _d(_m(data['sales'])['count']).round();
  double get _purch =>
      _web ? _d(_m(data['buy'])['purchases']) : _d(data['totalPurchases']);
  double get _exp =>
      _web ? _d(_m(data['buy'])['expenses']) : _d(data['totalExpenses']);
  double get _costs => _purch + _exp;
  int get _buyCount => _d(_m(data['buy'])['count']).round();
  Map<String, dynamic> get _pay => _m(data['payables']);

  /// [{label, sales, costs}]
  List<Map<String, dynamic>> get _trend {
    if (data['trend'] is List) {
      return _l(data['trend'])
          .map(
            (t) => {
              'label': '${t['label'] ?? t['month'] ?? ''}',
              'sales': _d(t['sales']),
              'costs': _d(t['costs']),
            },
          )
          .toList();
    }
    final s = _l(data['monthlySales']),
        p = _l(data['monthlyPurchases']),
        e = _l(data['monthlyExpenses']);
    return List.generate(
      s.length,
      (i) => {
        'label': '${s[i]['month']}'.split(' ').first,
        'sales': _d(s[i]['sales']),
        'costs':
            (i < p.length ? _d(p[i]['purchases']) : 0.0) +
            (i < e.length ? _d(e[i]['expenses']) : 0.0),
      },
    );
  }

  bool get _zh => AppLocalizations.of(context).locale.languageCode == 'zh';
  String _t(String en, String zh) => _zh ? zh : en;

  String _name() {
    final auth = Provider.of<AuthProvider>(context, listen: false) as dynamic;
    for (final get in [
      () => auth.fullName,
      () => auth.name,
      () => auth.firstName,
      () => auth.username,
    ]) {
      try {
        final v = get();
        if (v != null && '$v'.trim().isNotEmpty) {
          final w = '$v'.trim().split(' ').first;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        }
      } catch (_) {
        /* not on this provider */
      }
    }
    return _t('there', '');
  }

  String _range() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    DateTime? p(dynamic s, bool end) {
      final v = '$s'.trim();
      final d = DateTime.tryParse(v.length == 7 ? '$v-01' : v);
      if (d == null) return null;
      return end && v.length == 7 ? DateTime(d.year, d.month + 1, 0) : d;
    }

    String f(DateTime? d, dynamic raw) => d == null
        ? '$raw'
        : '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
    return '${f(p(auth.fromDate, false), auth.fromDate)} – ${f(p(auth.toDate, true), auth.toDate)}';
  }

  /* =========================================================
     UI
     ========================================================= */
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: _page,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text(
          loc.dashboard,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _muted),
            onPressed: fetchData,
          ),
        ],
      ),
      drawer: AppDrawer(selectedIndex: 0),
      body: Stack(
        children: [
          RefreshIndicator(
            color: _indigo,
            onRefresh: fetchData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
              children: [
                _hero(),
                const SizedBox(height: 14),
                if (failed)
                  _note(
                    Icons.error_outline_rounded,
                    _t(
                      "Couldn't load the dashboard. Pull down to try again.",
                      '无法加载仪表板，请下拉重试。',
                    ),
                    const Color(0xFFDC2626),
                  ),
                _tiles(loc),
                const SizedBox(height: 10),
                _taxTiles(),
                _chips(),
                const SizedBox(height: 14),
                _chartCard(),
                const SizedBox(height: 14),
                _ringCard(loc),
                const SizedBox(height: 14),
                _birCard(),
                _topCard(),
                _recentCard(),
              ],
            ),
          ),
          const ChatBubble(),
        ],
      ),
    );
  }

  /* ---------- hero ---------- */
  Widget _hero() {
    final h = DateTime.now().hour;
    final greet = h < 12
        ? AppLocalizations.of(context).goodMorning
        : h < 18
        ? AppLocalizations.of(context).goodAfternoon
        : AppLocalizations.of(context).goodEvening;
    final sales = _salesTotal;
    final costs = _costs;
    final next = _deadlines()
        .where((d) => d.days >= 0)
        .cast<_Due?>()
        .firstWhere((_) => true, orElse: () => null);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  _range(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$greet, ${_name()} 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          isLoading
              ? Text(
                  _t('Loading your numbers…', '正在加载数据…'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(.85),
                    fontSize: 13.5,
                  ),
                )
              : Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.white.withOpacity(.88),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: _t('You made ', '本期销售 ')),
                      TextSpan(
                        text: _money(sales),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(text: _t(' in sales and spent ', '，支出 ')),
                      TextSpan(
                        text: _money(costs),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(text: _t(' this period.', '。')),
                    ],
                  ),
                ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.25)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('NEXT BIR DEADLINE', '下一个 BIR 截止日'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${next.days}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            next.days == 1 ? _t('day', '天') : _t('days', '天'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${next.form} · ${next.period}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtDate(next.due),
                          style: TextStyle(
                            color: Colors.white.withOpacity(.8),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _urgencyPill(next.days, light: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /* ---------- KPI tiles: Sales · Purchases & expenses · Accounts receivable · Accounts payable ---------- */
  Widget _tiles(AppLocalizations loc) {
    final tr = _trend;
    final List<double> sSpark = tr
        .map<double>((t) => t['sales'] as double)
        .toList();
    final List<double> cSpark = tr
        .map<double>((t) => t['costs'] as double)
        .toList();
    final ar = _m(_pay['ar']), ap = _m(_pay['ap']);
    final hasAr = ar.isNotEmpty || ap.isNotEmpty;
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';

    final tiles = [
      _Tile(
        AppLocalizations.of(context).sales,
        _salesTotal,
        Icons.receipt_long_rounded,
        _gSales,
        sSpark,
        money: true,
        sub: _web
            ? plural(_salesCount, _t('invoice', '张发票'), _t('invoices', '张发票'))
            : null,
      ),
      _Tile(
        _t('Purchases & expenses', '采购与费用'),
        _costs,
        Icons.shopping_cart_rounded,
        _gCosts,
        cSpark,
        money: true,
        sub: _web
            ? plural(_buyCount, _t('record', '条记录'), _t('records', '条记录'))
            : null,
      ),
      _Tile(
        _t('Accounts receivable', '应收账款'),
        _d(ar['total']),
        Icons.account_balance_wallet_rounded,
        _gCust,
        null,
        money: true,
        missing: !hasAr,
        sub: hasAr
            ? '${plural(_d(ar['count']).round(), _t('unpaid invoice', '张未收发票'), _t('unpaid invoices', '张未收发票'))} · ${_t('no receipt yet', '未收款')}'
            : null,
      ),
      _Tile(
        _t('Accounts payable', '应付账款'),
        _d(ap['total']),
        Icons.shopping_bag_rounded,
        _gVend,
        null,
        money: true,
        missing: !hasAr,
        sub: hasAr
            ? '${plural(_d(ap['count']).round(), _t('unpaid bill', '张未付账单'), _t('unpaid bills', '张未付账单'))} · ${_t('no payment yet', '未付款')}'
            : null,
      ),
    ];
    return _grid(tiles.map(_tile).toList());
  }

  /* ---------- tax payables (web: /bir/payables + income tax) ---------- */
  double? _taxVal(String key) {
    final p = _m(_pay[key]);
    if (key == 'comp')
      return p.isEmpty
          ? (data.containsKey('compPayable') ? _d(data['compPayable']) : null)
          : (_d(p['returns']) > 0 ? _d(p['filed']) : null);
    if (p.isNotEmpty) return _d(p['books']);
    const flat = {'vat': 'vatPayable', 'ewt': 'ewtPayable'};
    return data.containsKey(flat[key]) ? _d(data[flat[key]]) : null;
  }

  double? get _incomeTax => data.containsKey('income_tax')
      ? _d(data['income_tax'])
      : data.containsKey('incomeTaxPayable')
      ? _d(data['incomeTaxPayable'])
      : null;

  bool get _hasTax =>
      _pay.isNotEmpty ||
      [
        'vatPayable',
        'ewtPayable',
        'incomeTaxPayable',
        'compPayable',
        'income_tax',
      ].any(data.containsKey);

  Widget _taxTiles() {
    String? pill(String key) {
      final p = _m(_pay[key]);
      if (p.isEmpty) return null;
      if (_d(p['returns']) <= 0) return _t('Not filed', '未申报');
      final bal = _d(p['balance']);
      return bal > 0.009
          ? '${_t('Unpaid', '未付')} ${_money(bal)}'
          : _t('Filed · Paid', '已申报 · 已付');
    }

    _Tile tx(
      String key,
      String label,
      String neg,
      String hint,
      double? v,
      IconData i,
      List<Color> g,
    ) {
      final val = v ?? 0;
      return _Tile(
        val < 0 ? neg : label,
        val.abs(),
        i,
        g,
        null,
        money: true,
        sub: hint,
        pill: pill(key),
        missing: v == null,
      );
    }

    final t = [
      tx(
        'vat',
        _t('VAT payable', '应付增值税'),
        _t('Excess input VAT', '进项税留抵'),
        _t('Output − Input VAT', '销项 − 进项'),
        _taxVal('vat'),
        Icons.description_outlined,
        _gVat,
      ),
      tx(
        'ewt',
        _t('Withholding tax payable', '应付预扣税'),
        _t('Withholding tax payable', '应付预扣税'),
        _t('EWT on purchases & expenses', '采购及费用预扣'),
        _taxVal('ewt'),
        Icons.shopping_bag_outlined,
        _gEwt,
      ),
      tx(
        'income',
        _t('Income tax payable', '应付所得税'),
        _t('Income tax (excess credits)', '所得税（多缴抵免）'),
        _t('From Income Tax Summary', '来自所得税汇总'),
        _incomeTax,
        Icons.bar_chart_rounded,
        _gInc,
      ),
      tx(
        'comp',
        _t('Compensation payable', '应付薪资预扣'),
        _t('Compensation payable', '应付薪资预扣'),
        _t('Withholding on compensation (1601-C)', '薪资预扣 (1601-C)'),
        _taxVal('comp'),
        Icons.account_balance_wallet_outlined,
        _gComp,
      ),
    ];
    return _grid(t.map(_tile).toList());
  }

  /* ---------- needs attention ---------- */
  Widget _chips() {
    final a = _m(data['attention']);
    if (a.isEmpty) return const SizedBox.shrink();
    final sc = _m(a['scanned']);
    final items = [
      [
        _d(a['tickets']),
        _t('Pending tickets', '待处理工单'),
        Icons.schedule_rounded,
        const Color(0xFFD97706),
      ],
      [
        _d(sc['sales']) + _d(sc['purchases']) + _d(sc['expenses']),
        _t('Scanned receipts', '已扫描收据'),
        Icons.description_outlined,
        const Color(0xFF2563EB),
      ],
      [
        _d(a['for_collection']),
        _t('For collection', '待收款'),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF059669),
      ],
      [
        _d(a['for_payment']),
        _t('For payment', '待付款'),
        Icons.shopping_cart_outlined,
        const Color(0xFFDB2777),
      ],
      [
        _d(a['unaudited']),
        _t('Not audited', '未审核'),
        Icons.check_box_outlined,
        const Color(0xFF7C3AED),
      ],
      [
        _d(a['out_of_stock']),
        _t('Out of stock', '缺货'),
        Icons.warning_amber_rounded,
        const Color(0xFFDC2626),
      ],
    ].where((c) => (c[0] as double) > 0).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (c[3] as Color).withOpacity(.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: (c[3] as Color).withOpacity(.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c[2] as IconData, size: 15, color: c[3] as Color),
                  const SizedBox(width: 6),
                  Text(
                    '${(c[0] as double).round()}',
                    style: TextStyle(
                      color: c[3] as Color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c[1] as String,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> items) => Column(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        items[i],
      ],
    ],
  );

  /// one metric per row: icon · label / value / note · sparkline or pill
  Widget _tile(_Tile t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: t.colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: t.colors.first.withOpacity(.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t.icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                isLoading
                    ? Container(
                        height: 20,
                        width: 120,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : t.missing
                    ? const Text(
                        '—',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _CountUp(
                          value: t.value,
                          format: t.money
                              ? _money
                              : (v) => v.round().toString(),
                        ),
                      ),
                if ((t.sub ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.82),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (t.spark != null && t.spark!.length > 1) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              height: 30,
              child: CustomPaint(painter: _Spark(t.spark!)),
            ),
          ],
          if (t.pill != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                t.pill!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /* ---------- Sales vs costs ---------- */
  Widget _chartCard() {
    final tr = _trend;
    final n = tr.length;
    final sales = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), tr[i]['sales'] as double),
    );
    final costs = List.generate(
      n,
      (i) => FlSpot(i.toDouble(), tr[i]['costs'] as double),
    );
    final labels = tr.map((t) => '${t['label']}').toList();
    final maxY =
        [...sales, ...costs].fold<double>(1, (m, x) => math.max(m, x.y)) * 1.15;

    return _cardBox(
      title: _t('Sales vs costs', '销售与成本'),
      trailing: Wrap(
        spacing: 10,
        children: [
          _legend(_indigo, AppLocalizations.of(context).sales),
          _legend(_orange, _t('Purchases & expenses', '采购与费用')),
        ],
      ),
      child: SizedBox(
        height: 210,
        child: isLoading || n == 0
            ? _skeleton(210)
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: _line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxY / 4,
                        getTitlesWidget: (v, _) => Text(
                          _short(v),
                          style: const TextStyle(color: _faint, fontSize: 9.5),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length || v != i.toDouble())
                            return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: const TextStyle(
                                color: _faint,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _series(costs, _orange, 2.5),
                    _series(sales, _indigo, 3),
                  ],
                ),
              ),
      ),
    );
  }

  LineChartBarData _series(List<FlSpot> spots, Color c, double w) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: c,
        barWidth: w,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 3.5,
            color: c,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [c.withOpacity(.35), c.withOpacity(0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );

  /* ---------- cost ring (like the web VAT ring) ---------- */
  Widget _ringCard(AppLocalizations loc) {
    final pv = _m(_pay['vat']);
    final hasVat = pv['output'] != null || _m(data['sales']).containsKey('vat');
    if (hasVat) return _vatCard(pv);
    final p = _purch;
    final e = _exp;
    return _cardBox(
      title: loc.costBreakdown,
      child: isLoading
          ? _skeleton(140)
          : Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _Ring(p, e),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _t('Total', '合计'),
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                          Text(
                            _short(p + e),
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ringRow(
                        const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        loc.purchases,
                        p,
                      ),
                      const SizedBox(height: 12),
                      _ringRow(
                        const [Color(0xFF06B6D4), Color(0xFF10B981)],
                        loc.expenses,
                        e,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _ringRow(List<Color> g, String label, double v) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: g),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 12.5),
        ),
      ),
      Text(
        _money(v),
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    ],
  );

  /// web: "VAT this period" – ring of Output vs Input VAT, Payable / Excess in the middle
  Widget _vatCard(Map<String, dynamic> pv) {
    final out = pv['output'] != null
        ? _d(pv['output'])
        : _d(_m(data['sales'])['vat']);
    final inp = pv['input'] != null
        ? _d(pv['input'])
        : _d(_m(data['buy'])['vat']);
    final payable = pv['books'] != null
        ? _d(pv['books'])
        : (data.containsKey('vat_payable')
              ? _d(data['vat_payable'])
              : out - inp);
    return _cardBox(
      title: _t('VAT this period', '本期增值税'),
      child: isLoading
          ? _skeleton(140)
          : Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _Ring(out, inp),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            payable >= 0
                                ? _t('Payable', '应付')
                                : _t('Excess', '留抵'),
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                          Text(
                            '₱${_short(payable.abs())}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ringRow(
                        const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        _t('Output VAT', '销项税'),
                        out,
                      ),
                      const SizedBox(height: 12),
                      _ringRow(
                        const [Color(0xFF06B6D4), Color(0xFF10B981)],
                        _t('Input VAT', '进项税'),
                        inp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// web: Top customers (bars)
  Widget _topCard() {
    final list = _l(data['top_customers']);
    if (!_web) return const SizedBox.shrink();
    final top = list.fold<double>(1, (m, c) => math.max(m, _d(c['total'])));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _cardBox(
        title: _t('Top customers', '主要客户'),
        child: list.isEmpty
            ? Text(
                _t('No sales in this period yet.', '本期暂无销售。'),
                style: const TextStyle(color: _muted, fontSize: 13),
              )
            : Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: _indigo,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${list[i]['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '₱${_short(_d(list[i]['total']))}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                Container(
                                  height: 7,
                                  color: const Color(0xFFF1F5F9),
                                ),
                                FractionallySizedBox(
                                  widthFactor: (_d(list[i]['total']) / top)
                                      .clamp(0, 1)
                                      .toDouble(),
                                  child: Container(
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFFEC4899),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_d(list[i]['invoices']).round()} ${_t('invoices', '张发票')}',
                            style: const TextStyle(color: _faint, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// web: Recent invoices
  Widget _recentCard() {
    final list = _l(data['recent']);
    if (!_web) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _cardBox(
        title: _t('Recent invoices', '最近发票'),
        child: list.isEmpty
            ? Text(
                _t('No invoices yet.', '暂无发票。'),
                style: const TextStyle(color: _muted, fontSize: 13),
              )
            : Column(
                children: [
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEEF2FF),
                            child: Text(
                              '${r['customer'] ?? '?'}'.isEmpty
                                  ? '?'
                                  : '${r['customer']}'[0].toUpperCase(),
                              style: const TextStyle(
                                color: _indigo,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['customer'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    _dateText(r['transaction_date']),
                                    if ((r['status'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      '${r['status']}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _money(_d(r['grand_total'])),
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _dateText(dynamic s) {
    final d = DateTime.tryParse('$s');
    return d == null ? '${s ?? ''}' : _fmtDate(d);
  }

  /* ---------- BIR calendar ---------- */
  Widget _birCard() {
    final list = _deadlines().where((d) => d.days >= -5).take(6).toList();
    return _cardBox(
      title: _t('BIR calendar', 'BIR 日历'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _seg([_t('VAT', '增值税'), _t('Non-VAT', '非增值税')], _vat ? 0 : 1, (
                i,
              ) {
                setState(() => _vat = i == 0);
                _savePref('home.vat', i == 0);
              }),
              const SizedBox(width: 8),
              _seg([_t('Corp', '公司'), _t('Indiv', '个人')], _corp ? 0 : 1, (i) {
                setState(() => _corp = i == 0);
                _savePref('home.corp', i == 0);
              }),
            ],
          ),
          const SizedBox(height: 12),
          for (final d in list) _timelineRow(d),
        ],
      ),
    );
  }

  Widget _timelineRow(_Due d) {
    final c = _urgencyColor(d.days);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                Text(
                  _months[d.due.month - 1].toUpperCase(),
                  style: TextStyle(
                    color: c,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${d.due.day}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.form,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${d.title} · ${d.period}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _urgencyPill(d.days),
        ],
      ),
    );
  }

  Widget _seg(List<String> opts, int on, ValueChanged<int> pick) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < opts.length; i++)
          GestureDetector(
            onTap: () => pick(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: i == on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: i == on
                    ? [
                        BoxShadow(
                          color: _ink.withOpacity(.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                opts[i],
                style: TextStyle(
                  color: i == on ? _indigo : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /* ---------- small pieces ---------- */
  Widget _cardBox({
    required String title,
    Widget? trailing,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: _ink.withOpacity(.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 6), trailing],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _legend(Color c, String l) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(l, style: const TextStyle(color: _muted, fontSize: 11.5)),
    ],
  );

  Widget _skeleton(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
    ),
  );

  Widget _note(IconData i, String t, Color c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withOpacity(.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.withOpacity(.3)),
    ),
    child: Row(
      children: [
        Icon(i, color: c, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(t, style: TextStyle(color: c, fontSize: 13)),
        ),
      ],
    ),
  );

  Color _urgencyColor(int days) => days < 0
      ? const Color(0xFFDC2626)
      : days <= 3
      ? const Color(0xFFEA580C)
      : days <= 10
      ? const Color(0xFFD97706)
      : const Color(0xFF059669);

  Widget _urgencyPill(int days, {bool light = false}) {
    final txt = days < 0
        ? _t('${-days}d late', '逾期 ${-days} 天')
        : days == 0
        ? _t('Today', '今天')
        : days == 1
        ? _t('Tomorrow', '明天')
        : _t('in $days days', '$days 天后');
    final c = _urgencyColor(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: light ? Colors.white.withOpacity(.22) : c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: light ? Colors.white : c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _money(num v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final s = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${neg ? '−' : ''}₱$s.${parts[1]}';
  }

  String _short(num n) {
    final v = n.abs();
    final s = v >= 1e9
        ? '${(v / 1e9).toStringAsFixed(1)}B'
        : v >= 1e6
        ? '${(v / 1e6).toStringAsFixed(1)}M'
        : v >= 1e3
        ? '${(v / 1e3).toStringAsFixed(1)}K'
        : v.toStringAsFixed(0);
    return '${n < 0 ? '−' : ''}$s';
  }

  String _fmtDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

  /* ---------- BIR filing calendar (same rules as the web Home) ---------- */
  List<_Due> _deadlines() {
    final out = <_Due>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int y, int m, int day) {
      final last = DateTime(y, m + 1, 0).day; // m is 1-based here
      return DateTime(y, m, math.min(day, last));
    }

    for (var y = now.year - 1; y <= now.year + 1; y++) {
      for (var m = 1; m <= 12; m++) {
        final label = '${_months[m - 1]} $y';
        final ny = m == 12 ? y + 1 : y;
        final nm = m == 12 ? 1 : m + 1;
        out.add(
          _Due(
            '1601-C',
            _t('Withholding Tax on Compensation', '薪资预扣税'),
            at(ny, nm, 10),
            label,
          ),
        );
        out.add(
          _Due(
            '0619-E',
            _t('Expanded Withholding Tax remittance', '扩大预扣税缴纳'),
            at(ny, nm, 10),
            label,
          ),
        );
        if (m % 3 == 0) {
          final q = m ~/ 3;
          final ql = 'Q$q $y';
          out.add(
            _Due(
              '1601-EQ',
              _t('Quarterly Expanded Withholding Tax + QAP', '季度扩大预扣税 + QAP'),
              at(ny, nm, 31),
              ql,
            ),
          );
          if (_vat) {
            out.add(
              _Due(
                '2550Q',
                _t('Quarterly VAT Return + SAWT', '季度增值税申报 + SAWT'),
                at(ny, nm, 25),
                ql,
              ),
            );
            out.add(
              _Due(
                'SLSP',
                _t('Summary List of Sales & Purchases', '销售与采购汇总表'),
                at(ny, nm, 25),
                ql,
              ),
            );
          } else {
            out.add(
              _Due(
                '2551Q',
                _t('Quarterly Percentage Tax', '季度百分比税'),
                at(ny, nm, 25),
                ql,
              ),
            );
          }
          if (q <= 3) {
            final mm = [5, 8, 11][q - 1];
            out.add(
              _corp
                  ? _Due(
                      '1702Q',
                      _t('Quarterly Income Tax (Corporation)', '季度所得税（公司）'),
                      at(y, mm, 29),
                      ql,
                    )
                  : _Due(
                      '1701Q',
                      _t('Quarterly Income Tax (Individual)', '季度所得税（个人）'),
                      at(y, mm, 15),
                      ql,
                    ),
            );
          }
        }
      }
      out.add(
        _Due(
          '1604-C',
          _t('Annual Info Return – Compensation (Alphalist)', '年度薪资信息申报'),
          at(y, 1, 31),
          'CY ${y - 1}',
        ),
      );
      out.add(
        _Due(
          '1604-E',
          _t('Annual Info Return – Expanded Withholding', '年度扩大预扣信息申报'),
          at(y, 3, 1),
          'CY ${y - 1}',
        ),
      );
      out.add(
        _corp
            ? _Due(
                '1702-RT',
                _t('Annual Income Tax (Corporation)', '年度所得税（公司）'),
                at(y, 4, 15),
                'CY ${y - 1}',
              )
            : _Due(
                '1701',
                _t('Annual Income Tax (Individual)', '年度所得税（个人）'),
                at(y, 4, 15),
                'CY ${y - 1}',
              ),
      );
    }
    for (final d in out) {
      d.days = d.due.difference(today).inDays;
    }
    final list = out.where((d) => d.days >= -5 && d.days <= 120).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    return list;
  }
}

/* =========================================================
   pieces
   ========================================================= */
class _Tile {
  _Tile(
    this.label,
    this.value,
    this.icon,
    this.colors,
    this.spark, {
    this.money = false,
    this.sub,
    this.pill,
    this.missing = false,
  });
  final String label;
  final double value;
  final IconData icon;
  final List<Color> colors;
  final List<double>? spark;
  final bool money;
  final String? sub;
  final String? pill;
  final bool missing;
}

class _Due {
  _Due(this.form, this.title, this.due, this.period);
  final String form;
  final String title;
  final DateTime due;
  final String period;
  int days = 0;
}

/// number that counts up to its value (₱0 → ₱45,942,161.84), like the web
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.format});
  final double value;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value),
    duration: const Duration(milliseconds: 1200),
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => Text(
      format(v),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _Spark extends CustomPainter {
  _Spark(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size s) {
    final mx = values.fold<double>(1, math.max);
    final mn = math.min(0.0, values.fold<double>(0, math.min));
    Offset pt(int i) => Offset(
      i / (values.length - 1) * s.width,
      s.height -
          ((values[i] - mn) / ((mx - mn) == 0 ? 1 : (mx - mn))) *
              (s.height - 4) -
          2,
    );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(area, Paint()..color = Colors.white.withOpacity(.18));
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Spark old) => old.values != values;
}

class _Ring extends CustomPainter {
  _Ring(this.a, this.b);
  final double a, b;

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      s.width - stroke,
      s.height - stroke,
    );
    final total = math.max(1.0, a + b);
    final aSweep = 2 * math.pi * (a / total);
    Paint p(List<Color> c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: c).createShader(rect);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x33949EB8),
    );
    if (a > 0)
      canvas.drawArc(
        rect,
        -math.pi / 2,
        aSweep,
        false,
        p(const [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
      );
    if (b > 0)
      canvas.drawArc(
        rect,
        -math.pi / 2 + aSweep,
        2 * math.pi - aSweep,
        false,
        p(const [Color(0xFF06B6D4), Color(0xFF10B981)]),
      );
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.a != a || old.b != b;
}
