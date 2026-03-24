import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> data = {};
  bool isLoading = true;
  int _touchedPieIndex = -1;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Theme colors
  static const _bg = Color(0xFF0B0F1A);
  static const _card = Color(0xFF111827);
  static const _accent = Color(0xFF6C63FF);
  static const _accentGreen = Color(0xFF10B981);
  static const _accentOrange = Color(0xFFF59E0B);
  static const _accentRed = Color(0xFFEF4444);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _textPrimary = Color(0xFFF9FAFB);
  static const _textSecondary = Color(0xFF9CA3AF);
  static const _divider = Color(0xFF1F2937);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/dashboard.php'
          '?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
          isLoading = false;
        });
        _animController.forward();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String formatNumber(dynamic number) {
    if (number == null) return '0';
    double value = 0;
    if (number is num) {
      value = number.toDouble();
    } else if (number is String) {
      value = double.tryParse(number) ?? 0;
    }
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      drawer: AppDrawer(selectedIndex: 0),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: _accent,
                backgroundColor: _card,
                onRefresh: fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreeting(),
                      const SizedBox(height: 20),
                      _buildSummaryGrid(),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Revenue Overview', 'Last 6 Months'),
                      const SizedBox(height: 14),
                      _buildLineChart(),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Monthly Sales', 'Bar Chart'),
                      const SizedBox(height: 14),
                      _buildBarChart(
                        dataKey: 'monthlySales',
                        valueKey: 'sales',
                        maxKey: 'maxSales',
                        color: _accent,
                        secondColor: const Color(0xFF9C8FFF),
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        'Cost Breakdown',
                        'Purchases vs Expenses',
                      ),
                      const SizedBox(height: 14),
                      _buildPieChart(),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Monthly Purchases', 'Bar Chart'),
                      const SizedBox(height: 14),
                      _buildBarChart(
                        dataKey: 'monthlyPurchases',
                        valueKey: 'purchases',
                        maxKey: 'maxPurchases',
                        color: _accentBlue,
                        secondColor: const Color(0xFF93C5FD),
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Monthly Expenses', 'Bar Chart'),
                      const SizedBox(height: 14),
                      _buildBarChart(
                        dataKey: 'monthlyExpenses',
                        valueKey: 'expenses',
                        maxKey: 'maxExpenses',
                        color: _accentOrange,
                        secondColor: const Color(0xFFFCD34D),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: _accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Dashboard',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
          onPressed: fetchData,
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetIcon;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetIcon = Icons.wb_sunny_rounded;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetIcon = Icons.wb_cloudy_rounded;
    } else {
      greeting = 'Good Evening';
      greetIcon = Icons.nightlight_round;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent.withOpacity(0.15), _accentBlue.withOpacity(0.08)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(greetIcon, color: _accentOrange, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                'Here\'s your business overview',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final cards = [
      _CardData(
        'Total Sales',
        formatNumber(data['totalSales']),
        Icons.trending_up_rounded,
        _accentGreen,
        '+Sales',
      ),
      _CardData(
        'Purchases',
        formatNumber(data['totalPurchases']),
        Icons.shopping_bag_rounded,
        _accentBlue,
        'Bought',
      ),
      _CardData(
        'Expenses',
        formatNumber(data['totalExpenses']),
        Icons.receipt_long_rounded,
        _accentOrange,
        'Spent',
      ),
      _CardData(
        'Customers',
        formatNumber(data['NoOfCustomer']),
        Icons.people_alt_rounded,
        _accent,
        'Active',
      ),
      _CardData(
        'Vendors',
        formatNumber(data['noOfVendors']),
        Icons.storefront_rounded,
        const Color(0xFFEC4899),
        'Partners',
      ),
      _CardData(
        'Scanned',
        formatNumber(data['totalScanned']),
        Icons.qr_code_scanner_rounded,
        const Color(0xFF14B8A6),
        'QR Codes',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 110,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _buildStatCard(cards[i]),
    );
  }

  Widget _buildStatCard(_CardData card) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: card.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: card.color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(card.icon, color: card.color, size: 17),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  card.badge,
                  style: TextStyle(
                    color: card.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.value,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_accent, _accentBlue]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    final salesList = data['monthlySales'] as List? ?? [];
    final purchasesList = data['monthlyPurchases'] as List? ?? [];

    List<FlSpot> salesSpots = [];
    List<FlSpot> purchasesSpots = [];

    for (int i = 0; i < salesList.length; i++) {
      salesSpots.add(FlSpot(i.toDouble(), _toDouble(salesList[i]['sales'])));
    }
    for (int i = 0; i < purchasesList.length; i++) {
      purchasesSpots.add(
        FlSpot(i.toDouble(), _toDouble(purchasesList[i]['purchases'])),
      );
    }

    final months = salesList.map((m) => m['month'].toString()).toList();

    return _buildChartCard(
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: _divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= months.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        months[idx],
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (val, _) => Text(
                    '₱${formatNumber(val)}',
                    style: const TextStyle(color: _textSecondary, fontSize: 9),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: salesSpots,
                isCurved: true,
                color: _accentGreen,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: _accentGreen,
                    strokeWidth: 2,
                    strokeColor: _card,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _accentGreen.withOpacity(0.2),
                      _accentGreen.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              LineChartBarData(
                spots: purchasesSpots,
                isCurved: true,
                color: _accentBlue,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: _accentBlue,
                    strokeWidth: 2,
                    strokeColor: _card,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _accentBlue.withOpacity(0.15),
                      _accentBlue.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      legend: Row(
        children: [
          _buildLegendDot(_accentGreen, 'Sales'),
          const SizedBox(width: 16),
          _buildLegendDot(_accentBlue, 'Purchases'),
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required String dataKey,
    required String valueKey,
    required String maxKey,
    required Color color,
    required Color secondColor,
  }) {
    final list = data[dataKey] as List? ?? [];
    final maxY = _toDouble(data[maxKey]);
    final months = list.map((m) => m['month'].toString()).toList();

    return _buildChartCard(
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.15,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: const Color(0xFF1E293B),
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '₱${formatNumber(rod.toY)}',
                  const TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= months.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        months[idx],
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (val, _) => Text(
                    '₱${formatNumber(val)}',
                    style: const TextStyle(color: _textSecondary, fontSize: 9),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: _divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(list.length, (i) {
              final val = _toDouble(list[i][valueKey]);
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    gradient: LinearGradient(
                      colors: [color, secondColor],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final totalPurchases = _toDouble(data['totalPurchases']);
    final totalExpenses = _toDouble(data['totalExpenses']);
    final total = totalPurchases + totalExpenses;

    final sections = [
      PieChartSectionData(
        value: totalPurchases,
        title: total > 0
            ? '${(totalPurchases / total * 100).toStringAsFixed(1)}%'
            : '',
        color: _accentBlue,
        radius: _touchedPieIndex == 0 ? 70 : 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      PieChartSectionData(
        value: totalExpenses,
        title: total > 0
            ? '${(totalExpenses / total * 100).toStringAsFixed(1)}%'
            : '',
        color: _accentOrange,
        radius: _touchedPieIndex == 1 ? 70 : 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];

    return _buildChartCard(
      child: Row(
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 45,
                sectionsSpace: 3,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPieLegendItem(
                  'Purchases',
                  '₱${formatNumber(totalPurchases)}',
                  _accentBlue,
                  total > 0 ? totalPurchases / total : 0,
                ),
                const SizedBox(height: 16),
                _buildPieLegendItem(
                  'Expenses',
                  '₱${formatNumber(totalExpenses)}',
                  _accentOrange,
                  total > 0 ? totalExpenses / total : 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegendItem(
    String label,
    String value,
    Color color,
    double ratio,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({required Widget child, Widget? legend}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legend != null) ...[legend, const SizedBox(height: 14)],
          child,
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: _textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _CardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String badge;

  const _CardData(this.title, this.value, this.icon, this.color, this.badge);
}
