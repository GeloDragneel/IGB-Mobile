import 'package:flutter/material.dart';

class ReportDetailScreen extends StatelessWidget {
  final String reportName;

  const ReportDetailScreen({super.key, required this.reportName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(reportName)),
      backgroundColor: const Color(0xFF121826),
      body: Center(
        child: Text(
          'Report content for $reportName',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}