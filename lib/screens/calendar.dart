import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../widgets/navigation_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/api_constants.dart';
import '../widgets/chat_bubble.dart';

// Light palette (same as the other screens)
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _line = Color(0xFFE2E8F0);
const _indigo = Color(0xFF4F46E5);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  String? _errorMessage;

  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _leaveDurations = [];
  String? _employeeTimeout;

  @override
  void initState() {
    super.initState();
    _fetchCalendarData();
    _fetchLeaveTypes();
    _fetchLeaveDurations();
    _fetchEmployeeTimeout();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchCalendarData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConstants.baseUrl}/employe_calendar?employeeId=${authProvider.employeeId}',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success') {
          final Map<String, List<Map<String, dynamic>>> grouped = {};

          for (final item in data['invoices']) {
            final dateKey = item['Date'] as String;
            final color = _parseColor(item['Color'] ?? '#8f72ec');

            final event = {
              'id': item['ID'],
              'title': item['Title'] ?? '',
              'time': item['Token'] == 'Present'
                  ? item['Title'] ?? ''
                  : item['Token'] ?? '',
              'location': item['Token'] ?? '',
              'token': item['Token'] ?? '',
              'color': color,
              'icon': _tokenIcon(item['Token'] ?? ''),
              // raw fields for auto-fill
              'raw': item,
            };

            grouped[dateKey] ??= [];
            grouped[dateKey]!.add(event);
          }

          setState(() {
            _eventsByDate
              ..clear()
              ..addAll(grouped);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load calendar data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLeaveTypes() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/leave_type_list'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success') {
          setState(() {
            _leaveTypes = List<Map<String, dynamic>>.from(data['list']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLeaveDurations() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/leave_duration'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success') {
          setState(() {
            _leaveDurations = List<Map<String, dynamic>>.from(data['list']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchEmployeeTimeout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConstants.baseUrl}/employee_timeout?employeeId=${authProvider.employeeId}',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'Success') {
          setState(() {
            _employeeTimeout = data['list'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  // ── API submission ────────────────────────────────────────────────────────

  Future<void> _submitLeave({
    required int leaveID,
    required int employeeID,
    required int leaveTypeID,
    required int leaveDurationID,
    required String startDate,
    required String endDate,
    required String reason,
    required double totalDays,
    required int createdBy,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/leave_registration'),
            body: {
              'LeaveID': leaveID.toString(),
              'EmployeeID': employeeID.toString(),
              'LeaveTypeID': leaveTypeID.toString(),
              'LeaveDurationID': leaveDurationID.toString(),
              'StartDate': startDate,
              'EndDate': endDate,
              'Reason': reason,
              'TotalDays': totalDays.toString(),
              'CreatedBy': createdBy.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['result'] == 'Success';
        _showSnackBar(
          data['message'] ?? (success ? 'Saved!' : 'Failed'),
          success,
        );
        if (success) _fetchCalendarData();
      } else {
        _showSnackBar('Server error: ${response.statusCode}', false);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', false);
    }
  }

  Future<void> _submitOvertime({
    required int otSummaryID,
    required int payrollID,
    required String otDate,
    required int shiftID,
    required String shift,
    required String shiftCode,
    required String otStart,
    required String otEnd,
    required String remarks,
  }) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final workId = auth.workId;
      final employeeId = auth.employeeId;
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/overtime_registration'),
            body: {
              'OTSummaryID': otSummaryID.toString(),
              'WrkID': workId,
              'EmpID': employeeId,
              'OTDate': otDate,
              'ShiftID': shiftID.toString(),
              'Shift': shift,
              'ShiftCode': shiftCode,
              'OTStart': otStart,
              'OTEnd': otEnd,
              'Remarks': remarks,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['result'] == 'Success';
        _showSnackBar(
          data['message'] ?? (success ? 'Saved!' : 'Failed'),
          success,
        );
        if (success) _fetchCalendarData();
      } else {
        _showSnackBar('Server error: ${response.statusCode}', false);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  IconData _tokenIcon(String token) {
    switch (token) {
      case 'Holiday':
        return Icons.celebration;
      case 'Overtime':
        return Icons.access_time;
      case 'Leave':
        return Icons.beach_access;
      case 'Present':
        return Icons.check_circle_outline;
      default:
        return Icons.event;
    }
  }

  List<Map<String, dynamic>> get _selectedDayEvents {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return _eventsByDate[key] ?? [];
  }

  List<Color> _dotsForDay(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final events = _eventsByDate[key] ?? [];
    return events.map((e) => e['color'] as Color).take(3).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Parse "MMM dd, yyyy  hh:mm AM/PM" back to "yyyy-MM-dd HH:mm:ss" for PHP
  String _toDbDateTime(String display) {
    try {
      final cleaned = display.replaceAll(RegExp(r'\s+'), ' ').trim();
      final dt = DateFormat('MMM dd, yyyy hh:mm a').parse(cleaned);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return display;
    }
  }

  // Parse "MMM dd, yyyy" → "yyyy-MM-dd"
  String _toDbDate(String display) {
    try {
      final dt = DateFormat('MMM dd, yyyy').parse(display.trim());
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return display;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      drawer: AppDrawer(selectedIndex: 0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _ink,
        iconTheme: const IconThemeData(color: _ink),
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).calendar,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_rounded, color: _indigo),
            onPressed: () => setState(() {
              _currentMonth = DateTime.now();
              _selectedDate = DateTime.now();
            }),
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _indigo,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _muted),
            onPressed: _isLoading ? null : _fetchCalendarData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _line),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: _indigo,
                    onRefresh: _fetchCalendarData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                      children: [
                        _calendarCard(),
                        const SizedBox(height: 12),
                        _monthSummary(),
                        const SizedBox(height: 20),
                        _dayHeader(),
                        const SizedBox(height: 10),
                        if (_selectedDayEvents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: _buildEmptyState(),
                          )
                        else
                          ..._selectedDayEvents.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildEventCard(e),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          // Messenger (staff / employees)
          const ChatBubble(),
        ],
      ),
    );
  }

  // ── Calendar card (swipe left/right to change month) ───────────────────────

  void _shiftMonth(int by) {
    setState(
      () => _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + by,
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: _indigo,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _currentMonth = DateTime(picked.year, picked.month);
        _selectedDate = picked;
      });
    }
  }

  Widget _calendarCard() {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) _shiftMonth(1);
        if (v > 200) _shiftMonth(-1);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              child: Row(
                children: [
                  _navButton(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(_currentMonth),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more_rounded,
                              color: _indigo,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _navButton(Icons.chevron_right_rounded, () => _shiftMonth(1)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: d == 'Sun' || d == 'Sat' ? _faint : _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: _buildCalendarGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ── This month at a glance (also the color legend) ─────────────────────────

  Widget _monthSummary() {
    final prefix = DateFormat('yyyy-MM').format(_currentMonth);
    final counts = <String, int>{
      'Present': 0,
      'Leave': 0,
      'Overtime': 0,
      'Holiday': 0,
    };
    _eventsByDate.forEach((key, list) {
      if (!key.startsWith(prefix)) return;
      for (final e in list) {
        final t = e['token'] as String;
        if (counts.containsKey(t)) counts[t] = counts[t]! + 1;
      }
    });
    return Row(
      children: [
        Expanded(
          child: _statTile(
            'Present',
            counts['Present']!,
            const Color(0xFF10b981),
            Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Leave',
            counts['Leave']!,
            const Color(0xFF8b5cf6),
            Icons.beach_access_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Overtime',
            counts['Overtime']!,
            const Color(0xFF3b82f6),
            Icons.access_time_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Holiday',
            counts['Holiday']!,
            const Color(0xFFec4899),
            Icons.celebration_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Selected day header ────────────────────────────────────────────────────

  Widget _dayHeader() {
    final n = _selectedDayEvents.length;
    return Row(
      children: [
        Container(
          width: 46,
          height: 50,
          decoration: BoxDecoration(
            color: _indigo,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(_selectedDate).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_selectedDate.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isToday(_selectedDate)
                    ? 'Today'
                    : DateFormat('EEEE').format(_selectedDate),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$n ${n == 1 ? 'activity' : 'activities'}',
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (n > 0)
          IconButton(
            tooltip: 'See all',
            onPressed: () =>
                _showAllEventsSheet(_selectedDate, _selectedDayEvents),
            icon: const Icon(
              Icons.format_list_bulleted_rounded,
              color: _muted,
              size: 20,
            ),
          ),
        ElevatedButton.icon(
          onPressed: () => _showEntryTypeDialog(_selectedDate),
          style: ElevatedButton.styleFrom(
            backgroundColor: _indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Add',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ── Small widgets ──────────────────────────────────────────────────────────

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: const Color(0xFF64748B), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: const Color(0xFFCBD5E1), size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchCalendarData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available, color: const Color(0xFFCBD5E1), size: 44),
          const SizedBox(height: 10),
          Text(
            'No activities for this day',
            style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _showEntryTypeDialog(_selectedDate),
            child: const Text(
              '+ Add Activity',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF4F6FB),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: _ink, size: 20),
        ),
      ),
    );
  }

  // ── Event card — now tappable to open edit dialog ─────────────────────────

  Widget _buildEventCard(Map<String, dynamic> event) {
    final color = event['color'] as Color;
    final token = event['token'] as String;
    final title = event['title'] as String;
    final time = event['time'] as String;
    final isEditable = token == 'Overtime' || token == 'Leave';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEditable ? () => _onEventCardTap(event) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    event['icon'] as IconData,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              token,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (time.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.schedule_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isEditable)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _faint,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Route tapped event to the correct edit dialog
  void _onEventCardTap(Map<String, dynamic> event) {
    final token = event['token'] as String;
    final raw = event['raw'] as Map<String, dynamic>? ?? {};

    // Derive a DateTime for the dialog header from the selected date
    final date = _selectedDate;

    if (token == 'Overtime') {
      _showOvertimeDialog(date, existingData: raw);
    } else if (token == 'Leave') {
      _showLeaveDialog(date, existingData: raw);
    }
  }

  void _showAllEventsSheet(DateTime date, List<Map<String, dynamic>> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isToday(date)
                                  ? 'TODAY'
                                  : DateFormat(
                                      'EEEE, MMM d',
                                    ).format(date).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${events.length} ${events.length == 1 ? 'Activity' : 'Activities'}',
                              style: TextStyle(
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: const Color(0xFFE2E8F0), height: 1),
                  ],
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available,
                              color: const Color(0xFFCBD5E1),
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No activities',
                              style: TextStyle(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final color = event['color'] as Color;
                          final token = event['token'] as String;
                          final title = event['title'] as String;
                          final time = event['time'] as String;
                          final isEditable =
                              token == 'Overtime' || token == 'Leave';

                          return GestureDetector(
                            onTap: isEditable
                                ? () {
                                    Navigator.pop(context);
                                    _onEventCardTap(event);
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Icon(
                                        event['icon'] as IconData,
                                        color: color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: color.withValues(
                                                      alpha: 0.3,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  token,
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (time.isNotEmpty) ...[
                                                const SizedBox(width: 10),
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  color: const Color(
                                                    0xFF94A3B8,
                                                  ),
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    time,
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0xFF64748B,
                                                      ),
                                                      fontSize: 11,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isEditable)
                                      Icon(
                                        Icons.edit_outlined,
                                        color: color.withValues(alpha: 0.7),
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final sundayOffset = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    final List<Widget> cells = [];

    for (var i = 0; i < sundayOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected =
          date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isToday = _isToday(date);
      final dots = _dotsForDay(date);

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isToday
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              dots.isNotEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dots
                          .map(
                            (c) => Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : c,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : const SizedBox(height: 6),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }

  // ── Entry type chooser ─────────────────────────────────────────────────────

  void _showEntryTypeDialog(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Entry',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(date),
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBottomSheetOption(
              icon: Icons.access_time_rounded,
              label: AppLocalizations.of(context).overtime,
              subtitle: 'Log extra working hours',
              color: const Color(0xFF3b82f6),
              onTap: () {
                Navigator.pop(context);
                _showOvertimeDialog(date);
              },
            ),
            const SizedBox(height: 12),
            _buildBottomSheetOption(
              icon: Icons.beach_access_rounded,
              label: AppLocalizations.of(context).leave,
              subtitle: 'Request time off',
              color: const Color(0xFF8b5cf6),
              onTap: () {
                Navigator.pop(context);
                _showLeaveDialog(date);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF4F6FB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Overtime dialog ────────────────────────────────────────────────────────
  // existingData: raw API map for auto-fill (update mode); null = insert mode

  void _showOvertimeDialog(
    DateTime date, {
    Map<String, dynamic>? existingData,
  }) {
    final isUpdate =
        existingData != null &&
        int.tryParse(existingData['OTSummaryID']?.toString() ?? '0') != null &&
        int.parse(existingData['OTSummaryID'].toString()) > 0;

    // ── Auto-fill from existing data ────────────────────────────────────────
    String startDefault = '';
    String endDefault = '';

    if (isUpdate) {
      // OTStart / OTEnd come from DB as "yyyy-MM-dd HH:mm:ss" — reformat for display
      startDefault = _dbDateTimeToDisplay(
        existingData['OTStart']?.toString() ?? '',
      );
      endDefault = _dbDateTimeToDisplay(
        existingData['OTEnd']?.toString() ?? '',
      );
    } else if (_employeeTimeout != null) {
      try {
        final parts = _employeeTimeout!.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final tod = TimeOfDay(hour: hour, minute: minute);
        final dateStr = DateFormat('MMM dd, yyyy').format(date);
        startDefault = '$dateStr  ${tod.format(context)}';
      } catch (_) {}
    }

    final startController = TextEditingController(text: startDefault);
    final endController = TextEditingController(text: endDefault);
    final remarksController = TextEditingController(
      text: existingData?['Remarks']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b82f6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFF3b82f6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUpdate
                              ? 'Edit ${AppLocalizations.of(context).overtime}'
                              : AppLocalizations.of(context).overtime,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date),
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (isUpdate) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3b82f6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF3b82f6,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'EDIT',
                          style: TextStyle(
                            color: Color(0xFF3b82f6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionLabel('START DATE & TIME'),
                const SizedBox(height: 8),
                _buildDateTimeField(
                  controller: startController,
                  hint: 'Select start date & time',
                  icon: Icons.play_circle_outline,
                  iconColor: const Color(0xFF10b981),
                  onTap: () => _selectDateTime(context, startController, date),
                ),
                const SizedBox(height: 14),
                _buildSectionLabel('END DATE & TIME'),
                const SizedBox(height: 8),
                _buildDateTimeField(
                  controller: endController,
                  hint: 'Select end date & time',
                  icon: Icons.stop_circle_outlined,
                  iconColor: const Color(0xFFef4444),
                  onTap: () => _selectDateTime(context, endController, date),
                ),
                const SizedBox(height: 14),
                _buildSectionLabel('REMARKS'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: remarksController,
                  label: AppLocalizations.of(context).overtimeRemarks,
                  icon: Icons.edit_note_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: BorderSide(color: const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(AppLocalizations.of(context).cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (startController.text.isEmpty ||
                              endController.text.isEmpty) {
                            _showSnackBar(
                              'Please fill start and end date & time.',
                              false,
                            );
                            return;
                          }
                          Navigator.pop(context);
                          _submitOvertime(
                            otSummaryID:
                                int.tryParse(
                                  existingData?['OTSummaryID']?.toString() ??
                                      '0',
                                ) ??
                                0,
                            payrollID:
                                int.tryParse(
                                  existingData?['PayrollID']?.toString() ?? '0',
                                ) ??
                                0,
                            otDate: DateFormat('yyyy-MM-dd').format(date),
                            shiftID:
                                int.tryParse(
                                  existingData?['ShiftID']?.toString() ?? '0',
                                ) ??
                                0,
                            shift: existingData?['Shift']?.toString() ?? '',
                            shiftCode:
                                existingData?['ShiftCode']?.toString() ?? '',
                            otStart: _toDbDateTime(startController.text),
                            otEnd: _toDbDateTime(endController.text),
                            remarks: remarksController.text,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3b82f6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          isUpdate
                              ? AppLocalizations.of(context).update
                              : AppLocalizations.of(context).save,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Leave dialog ───────────────────────────────────────────────────────────

  void _showLeaveDialog(DateTime date, {Map<String, dynamic>? existingData}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUpdate =
        existingData != null &&
        int.tryParse(existingData['LeaveID']?.toString() ?? '0') != null &&
        int.parse(existingData['LeaveID'].toString()) > 0;

    // Find matching leave type name for auto-fill
    String leaveTypeName = '';
    if (isUpdate) {
      final typeId = existingData['LeaveTypeID']?.toString() ?? '';
      final match = _leaveTypes.firstWhere(
        (t) => t['LeaveTypeID']?.toString() == typeId,
        orElse: () => {},
      );
      leaveTypeName = match['LeaveTypeName']?.toString() ?? '';
    }

    // Find matching duration name for auto-fill
    String durationName = '';
    if (isUpdate) {
      final durId = existingData['LeaveDurationID']?.toString() ?? '';
      final match = _leaveDurations.firstWhere(
        (d) => d['LeaveDurationID']?.toString() == durId,
        orElse: () => {},
      );
      durationName = match['DurationName']?.toString() ?? '';
    }

    final leaveTypeController = TextEditingController(text: leaveTypeName);
    final leaveDurationController = TextEditingController(text: durationName);
    final startController = TextEditingController(
      text: isUpdate
          ? _dbDateToDisplay(existingData['StartDate']?.toString() ?? '')
          : DateFormat('MMM dd, yyyy').format(date),
    );
    final endController = TextEditingController(
      text: isUpdate
          ? _dbDateToDisplay(existingData['EndDate']?.toString() ?? '')
          : DateFormat('MMM dd, yyyy').format(date),
    );
    final reasonController = TextEditingController(
      text: existingData?['Reason']?.toString() ?? '',
    );

    // Track selected IDs so we can send them to PHP
    int selectedLeaveTypeId =
        int.tryParse(existingData?['LeaveTypeID']?.toString() ?? '0') ?? 0;
    int selectedDurationId =
        int.tryParse(existingData?['LeaveDurationID']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8b5cf6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.beach_access_rounded,
                          color: Color(0xFF8b5cf6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUpdate
                                ? 'Edit ${AppLocalizations.of(context).leaveRequest}'
                                : AppLocalizations.of(context).leaveRequest,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d').format(date),
                            style: TextStyle(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (isUpdate) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8b5cf6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF8b5cf6,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Color(0xFF8b5cf6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('LEAVE TYPE'),
                            const SizedBox(height: 8),
                            _buildDateTimeField(
                              controller: leaveTypeController,
                              hint: 'Select type',
                              icon: Icons.category_outlined,
                              iconColor: const Color(0xFF8b5cf6),
                              onTap: () => _showLeaveTypePicker(
                                leaveTypeController,
                                onSelected: (id) {
                                  setModalState(() => selectedLeaveTypeId = id);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('DURATION'),
                            const SizedBox(height: 8),
                            _buildDateTimeField(
                              controller: leaveDurationController,
                              hint: 'Select',
                              icon: Icons.timelapse_rounded,
                              iconColor: const Color(0xFFf59e0b),
                              onTap: () => _showLeaveDurationPicker(
                                leaveDurationController,
                                onSelected: (id) {
                                  setModalState(() => selectedDurationId = id);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSectionLabel('START DATE'),
                  const SizedBox(height: 8),
                  _buildDateTimeField(
                    controller: startController,
                    hint: 'Select start date',
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFF10b981),
                    onTap: () =>
                        _selectDateFormatted(context, startController, date),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionLabel('END DATE'),
                  const SizedBox(height: 8),
                  _buildDateTimeField(
                    controller: endController,
                    hint: 'Select end date',
                    icon: Icons.calendar_month_outlined,
                    iconColor: const Color(0xFFef4444),
                    onTap: () =>
                        _selectDateFormatted(context, endController, date),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionLabel('REASON'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: reasonController,
                    label: AppLocalizations.of(context).reason,
                    icon: Icons.edit_note_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: BorderSide(color: const Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(AppLocalizations.of(context).cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedLeaveTypeId == 0 ||
                                selectedDurationId == 0 ||
                                startController.text.isEmpty ||
                                endController.text.isEmpty) {
                              _showSnackBar(
                                'Please fill all required fields.',
                                false,
                              );
                              return;
                            }

                            // Calculate total days
                            double totalDays = 1;
                            try {
                              final s = DateFormat(
                                'MMM dd, yyyy',
                              ).parse(startController.text.trim());
                              final e = DateFormat(
                                'MMM dd, yyyy',
                              ).parse(endController.text.trim());
                              totalDays = e.difference(s).inDays.toDouble() + 1;
                            } catch (_) {}

                            Navigator.pop(context);
                            _submitLeave(
                              leaveID:
                                  int.tryParse(
                                    existingData?['LeaveID']?.toString() ?? '0',
                                  ) ??
                                  0,
                              employeeID:
                                  int.tryParse(authProvider.employeeId) ?? 0,
                              leaveTypeID: selectedLeaveTypeId,
                              leaveDurationID: selectedDurationId,
                              startDate: _toDbDate(startController.text),
                              endDate: _toDbDate(endController.text),
                              reason: reasonController.text,
                              totalDays: totalDays,
                              createdBy:
                                  int.tryParse(authProvider.employeeId) ?? 0,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8b5cf6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isUpdate
                                ? AppLocalizations.of(context).update
                                : AppLocalizations.of(context).save,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form field helpers ─────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4F46E5),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildDateTimeField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => Text(
                  value.text.isEmpty ? hint : value.text,
                  style: TextStyle(
                    color: value.text.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Icon(Icons.expand_more, color: const Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF0F172A)),
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5)),
        ),
      ),
    );
  }

  // ── Date / time pickers ────────────────────────────────────────────────────

  Future<void> _selectDateTime(
    BuildContext context,
    TextEditingController controller,
    DateTime initialDate,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4F46E5),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4F46E5),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    final formatted = DateFormat('MMM dd, yyyy').format(date);
    controller.text = '$formatted  ${time.format(context)}';
  }

  Future<void> _selectDateFormatted(
    BuildContext context,
    TextEditingController controller,
    DateTime initialDate,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4F46E5),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      controller.text = DateFormat('MMM dd, yyyy').format(date);
    }
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _showLeaveTypePicker(
    TextEditingController controller, {
    void Function(int id)? onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8b5cf6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_outlined,
                            color: Color(0xFF8b5cf6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Leave Type',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: const Color(0xFFE2E8F0), height: 1),
                  ],
                ),
              ),
              Expanded(
                child: _leaveTypes.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _leaveTypes.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: const Color(0xFFE2E8F0), height: 1),
                        itemBuilder: (context, index) {
                          final type = _leaveTypes[index];
                          final isPaid = type['IsPaid'] == '1';
                          final maxDays =
                              double.tryParse(type['MaxDays'] ?? '0') ?? 0;
                          return InkWell(
                            onTap: () {
                              controller.text = type['LeaveTypeName'] ?? '';
                              onSelected?.call(
                                int.tryParse(
                                      type['LeaveTypeID']?.toString() ?? '0',
                                    ) ??
                                    0,
                              );
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8b5cf6,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (type['LeaveTypeName'] as String? ??
                                            '?')[0],
                                        style: const TextStyle(
                                          color: Color(0xFF8b5cf6),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type['LeaveTypeName'] ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          type['Description'] ?? '',
                                          style: TextStyle(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPaid
                                              ? const Color(
                                                  0xFF10b981,
                                                ).withValues(alpha: 0.15)
                                              : const Color(
                                                  0xFFef4444,
                                                ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          isPaid ? 'Paid' : 'Unpaid',
                                          style: TextStyle(
                                            color: isPaid
                                                ? const Color(0xFF10b981)
                                                : const Color(0xFFef4444),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (maxDays > 0) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '${maxDays % 1 == 0 ? maxDays.toInt() : maxDays}d max',
                                          style: TextStyle(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveDurationPicker(
    TextEditingController controller, {
    void Function(int id)? onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.75,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFf59e0b,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timelapse_rounded,
                            color: Color(0xFFf59e0b),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Duration',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: const Color(0xFFE2E8F0), height: 1),
                  ],
                ),
              ),
              Expanded(
                child: _leaveDurations.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _leaveDurations.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: const Color(0xFFE2E8F0), height: 1),
                        itemBuilder: (context, index) {
                          final dur = _leaveDurations[index];
                          final hours =
                              double.tryParse(dur['Hours'] ?? '0') ?? 0;
                          return InkWell(
                            onTap: () {
                              controller.text = dur['DurationName'] ?? '';
                              onSelected?.call(
                                int.tryParse(
                                      dur['LeaveDurationID']?.toString() ?? '0',
                                    ) ??
                                    0,
                              );
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFf59e0b,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        hours > 0 ? '${hours.toInt()}h' : '∞',
                                        style: const TextStyle(
                                          color: Color(0xFFf59e0b),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dur['DurationName'] ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dur['Description'] ?? '',
                                          style: TextStyle(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: const Color(0xFFCBD5E1),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: success
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// DB "yyyy-MM-dd HH:mm:ss" → display "MMM dd, yyyy  hh:mm AM"
  String _dbDateTimeToDisplay(String db) {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(db);
      final datePart = DateFormat('MMM dd, yyyy').format(dt);
      final timePart = TimeOfDay.fromDateTime(dt).format(context);
      return '$datePart  $timePart';
    } catch (_) {
      return db;
    }
  }

  /// DB "yyyy-MM-dd" → display "MMM dd, yyyy"
  String _dbDateToDisplay(String db) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(db);
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return db;
    }
  }
}
