import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../widgets/navigation_drawer.dart';
import '../providers/auth_provider.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic> data = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final response = await http.get(
      Uri.parse(
        'https://igb-fems.com/LIVE/mobile_php/dashboard.php?userId=${auth.userId}&from=${auth.fromDate}&to=${auth.toDate}',
      ),
    );
    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Helper to format large numbers like 200000 -> 200K
  String formatNumber(dynamic number) {
    if (number == null) return '0';

    double value = 0;

    if (number is int || number is double) {
      value = number.toDouble();
    } else if (number is String) {
      value = double.tryParse(number) ?? 0;
    }

    if (value >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(1)}B';
    } else if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(1)}M';
    } else if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Dashboard')),
        drawer: AppDrawer(selectedIndex: 0),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      drawer: AppDrawer(selectedIndex: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: 20),
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Sales',
                      formatNumber(data['totalSales']),
                      Icons.bar_chart,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Purchases',
                      formatNumber(data['totalPurchases']),
                      Icons.shopping_cart,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Expenses',
                      formatNumber(data['totalExpenses']),
                      Icons.receipt,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Customers',
                      formatNumber(data['NoOfCustomer']),
                      Icons.people,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Vendors',
                      formatNumber(data['noOfVendors']),
                      Icons.business,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Scanned',
                      formatNumber(data['totalScanned']),
                      Icons.qr_code_scanner,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              Center(
                child: Text(
                  'Last 6 Months Sales',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data['maxSales'] is num)
                        ? data['maxSales'].toDouble()
                        : double.tryParse(data['maxSales'].toString()) ?? 0,

                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String formatted;
                          double value = rod.toY;
                          if (value >= 1000000) {
                            formatted =
                                '${(value / 1000000).toStringAsFixed(1)} M';
                          } else if (value >= 1000) {
                            formatted =
                                '${(value / 1000).toStringAsFixed(0)} K';
                          } else {
                            formatted = value.toStringAsFixed(0);
                          }
                          return BarTooltipItem(
                            formatted,
                            TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final months = data['monthlySales']
                                ?.map((m) => m['month'] as String)
                                .toList();
                            return Text(
                              months[value.toInt()],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            String formatted;
                            if (value >= 1000000) {
                              formatted =
                                  '${(value / 1000000).toStringAsFixed(1)}M';
                            } else if (value >= 1000) {
                              formatted =
                                  '${(value / 1000).toStringAsFixed(0)}K';
                            } else {
                              formatted = value.toStringAsFixed(0);
                            }
                            return Text(
                              '\₱$formatted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      data['monthlySales']?.length ?? 6,
                      (index) {
                        dynamic value = data['monthlySales']?[index]['sales'];
                        double sales = 0;
                        if (value is num) {
                          sales = value.toDouble();
                        } else if (value is String) {
                          sales = double.tryParse(value) ?? 0;
                        }
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: sales.toDouble(),
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              Center(
                child: Text(
                  'Last 6 Months Purchases',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data['maxPurchases'] is num)
                        ? data['maxPurchases'].toDouble()
                        : double.tryParse(data['maxPurchases'].toString()) ?? 0,

                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String formatted;
                          double value = rod.toY;
                          if (value >= 1000000) {
                            formatted =
                                '${(value / 1000000).toStringAsFixed(1)} M';
                          } else if (value >= 1000) {
                            formatted =
                                '${(value / 1000).toStringAsFixed(0)} K';
                          } else {
                            formatted = value.toStringAsFixed(0);
                          }
                          return BarTooltipItem(
                            formatted,
                            TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final months = data['monthlyPurchases']
                                ?.map((m) => m['month'] as String)
                                .toList();
                            return Text(
                              months[value.toInt()],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            String formatted;
                            if (value >= 1000000) {
                              formatted =
                                  '${(value / 1000000).toStringAsFixed(1)}M';
                            } else if (value >= 1000) {
                              formatted =
                                  '${(value / 1000).toStringAsFixed(0)}K';
                            } else {
                              formatted = value.toStringAsFixed(0);
                            }
                            return Text(
                              '\₱$formatted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      data['monthlyPurchases']?.length ?? 6,
                      (index) {
                        dynamic value =
                            data['monthlyPurchases']?[index]['purchases'];
                        double purchases = 0;
                        if (value is num) {
                          purchases = value.toDouble();
                        } else if (value is String) {
                          purchases = double.tryParse(value) ?? 0;
                        }
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: purchases.toDouble(),
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              Center(
                child: Text(
                  'Last 6 Months Expenses',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (data['maxExpenses'] is num)
                        ? data['maxExpenses'].toDouble()
                        : double.tryParse(data['maxExpenses'].toString()) ?? 0,

                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String formatted;
                          double value = rod.toY;
                          if (value >= 1000000) {
                            formatted =
                                '${(value / 1000000).toStringAsFixed(1)} M';
                          } else if (value >= 1000) {
                            formatted =
                                '${(value / 1000).toStringAsFixed(0)} K';
                          } else {
                            formatted = value.toStringAsFixed(0);
                          }
                          return BarTooltipItem(
                            formatted,
                            TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final months = data['monthlyExpenses']
                                ?.map((m) => m['month'] as String)
                                .toList();
                            return Text(
                              months[value.toInt()],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            String formatted;
                            if (value >= 1000000) {
                              formatted =
                                  '${(value / 1000000).toStringAsFixed(1)}M';
                            } else if (value >= 1000) {
                              formatted =
                                  '${(value / 1000).toStringAsFixed(0)}K';
                            } else {
                              formatted = value.toStringAsFixed(0);
                            }
                            return Text(
                              '\₱$formatted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      data['monthlyExpenses']?.length ?? 6,
                      (index) {
                        dynamic value =
                            data['monthlyExpenses']?[index]['expenses'];
                        double purchases = 0;
                        if (value is num) {
                          purchases = value.toDouble();
                        } else if (value is String) {
                          purchases = double.tryParse(value) ?? 0;
                        }
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: purchases.toDouble(),
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      color: Color(0xFF101222),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
