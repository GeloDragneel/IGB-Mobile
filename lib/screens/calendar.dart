import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../widgets/navigation_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/api_constants.dart';

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
              '${ApiConstants.baseUrl}/employe_calendar.php?employeeId=${authProvider.employeeId}',
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
          .get(Uri.parse('${ApiConstants.baseUrl}/leave_type_list.php'))
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
          .get(Uri.parse('${ApiConstants.baseUrl}/leave_duration.php'))
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
              '${ApiConstants.baseUrl}/employee_timeout.php?employeeId=${authProvider.employeeId}',
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
            Uri.parse('${ApiConstants.baseUrl}/leave_registration.php'),
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
            Uri.parse('${ApiConstants.baseUrl}/overtime_registration.php'),
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
      return const Color(0xFF8f72ec);
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
      backgroundColor: const Color(0xFF030710),
      drawer: AppDrawer(selectedIndex: 0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030710),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).calendar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Color(0xFF8f72ec)),
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
                      color: Color(0xFF8f72ec),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF8f72ec)),
            onPressed: _isLoading ? null : _fetchCalendarData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8f72ec)),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1923),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _navButton(Icons.chevron_left, () {
                              setState(() {
                                _currentMonth = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month - 1,
                                );
                              });
                            }),
                            Row(
                              children: [
                                Text(
                                  DateFormat(
                                    'MMMM yyyy',
                                  ).format(_currentMonth).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.unfold_more,
                                  color: Color(0xFF8f72ec),
                                  size: 16,
                                ),
                              ],
                            ),
                            _navButton(Icons.chevron_right, () {
                              setState(() {
                                _currentMonth = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month + 1,
                                );
                              });
                            }),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map(
                                (d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _legendDot(const Color(0xFFec4899), 'Holiday'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF3b82f6), 'Overtime'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF8b5cf6), 'Leave'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF10b981), 'Present'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isToday(_selectedDate)
                                      ? 'TODAY'
                                      : DateFormat(
                                          'EEEE, MMM d',
                                        ).format(_selectedDate).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF8f72ec),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedDayEvents.length} ${_selectedDayEvents.length == 1 ? 'Activity' : 'Activities'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _selectedDayEvents.isEmpty
                                  ? null
                                  : () => _showAllEventsSheet(
                                      _selectedDate,
                                      _selectedDayEvents,
                                    ),
                              icon: const Icon(
                                Icons.format_list_bulleted_rounded,
                                color: Color(0xFF8f72ec),
                                size: 15,
                              ),
                              label: const Text(
                                'See all',
                                style: TextStyle(
                                  color: Color(0xFF8f72ec),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _selectedDayEvents.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  itemCount: _selectedDayEvents.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _buildEventCard(
                                        _selectedDayEvents[index],
                                      ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: () => _showEntryTypeDialog(_selectedDate),
          backgroundColor: const Color(0xFF8f72ec),
          elevation: 8,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: Colors.grey[700], size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchCalendarData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8f72ec),
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
          Icon(Icons.event_available, color: Colors.grey[700], size: 44),
          const SizedBox(height: 10),
          Text(
            'No activities for this day',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _showEntryTypeDialog(_selectedDate),
            child: const Text(
              '+ Add Activity',
              style: TextStyle(color: Color(0xFF8f72ec)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF1A2332),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 18),
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
        color: const Color(0xFF0F1923),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
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
                          color: Colors.white,
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
                              color: Colors.grey[600],
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: Colors.grey[500],
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
            color: Color(0xFF0F1923),
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                                color: Color(0xFF8f72ec),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${events.length} ${events.length == 1 ? 'Activity' : 'Activities'}',
                              style: TextStyle(
                                color: Colors.grey[500],
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
                              0xFF8f72ec,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF8f72ec,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: const TextStyle(
                              color: Color(0xFF8f72ec),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
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
                              color: Colors.grey[700],
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No activities',
                              style: TextStyle(
                                color: Colors.grey[600],
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
                                color: const Color(0xFF1A2332),
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
                                              color: Colors.white,
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
                                                  color: Colors.grey[600],
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    time,
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
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
                      ? const Color(0xFF8f72ec)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: const Color(0xFF8f72ec), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isToday
                          ? const Color(0xFF8f72ec)
                          : Colors.white,
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
          color: Color(0xFF0F1923),
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
                color: Colors.white.withValues(alpha: 0.15),
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
                    color: const Color(0xFF8f72ec).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF8f72ec),
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
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
      color: const Color(0xFF1A2332),
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
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
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
            color: Color(0xFF0F1923),
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
                      color: Colors.white.withValues(alpha: 0.15),
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
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date),
                          style: TextStyle(
                            color: Colors.grey[500],
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
                          foregroundColor: Colors.grey[400],
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
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
              color: Color(0xFF0F1923),
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
                        color: Colors.white.withValues(alpha: 0.15),
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
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d').format(date),
                            style: TextStyle(
                              color: Colors.grey[500],
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
                            foregroundColor: Colors.grey[400],
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
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
        color: Color(0xFF8f72ec),
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
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: value.text.isEmpty ? Colors.grey[600] : Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Icon(Icons.expand_more, color: Colors.grey[600], size: 18),
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
      style: const TextStyle(color: Colors.white),
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: const Color(0xFF8f72ec), size: 20),
        filled: true,
        fillColor: const Color(0xFF0F1923),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8f72ec)),
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
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8f72ec),
            onPrimary: Colors.white,
            surface: Color(0xFF1A2332),
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
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8f72ec),
            onPrimary: Colors.white,
            surface: Color(0xFF1A2332),
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
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8f72ec),
            onPrimary: Colors.white,
            surface: Color(0xFF1A2332),
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
            color: Color(0xFF0F1923),
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _leaveTypes.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8f72ec),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _leaveTypes.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1,
                        ),
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
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          type['Description'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[500],
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
                                            color: Colors.grey[600],
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
            color: Color(0xFF0F1923),
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _leaveDurations.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8f72ec),
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        itemCount: _leaveDurations.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1,
                        ),
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
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dur['Description'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[700],
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
            ? const Color(0xFF1A3A2A)
            : const Color(0xFF3A1A1A),
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
