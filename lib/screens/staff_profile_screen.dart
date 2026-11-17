// Staff "My profile" (route /myProfile) — same as the web Profile.jsx
//   Personal · Contact  → editable
//   Work · Shift · Banks · photo → view only (photo can be changed)
//   Leave & OT → calendar (tap a day to file leave / overtime) + my requests with status
// Only for staff logins (m_user_staff): the server's /hr/my-profile says is_staff.
//
// pubspec.yaml:  http: ^1.2.0   image_picker: ^1.1.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/* =========================================================
   API — plug in your base URL and token
   ========================================================= */
class HrApiException implements Exception {
  HrApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HrApi {
  HrApi({
    required this.baseUrl,
    required this.token,
    this.extraHeaders,
    this.params,
  });

  /// e.g. http://10.0.2.2:8000/api  (emulator) · http://192.168.1.10:8000/api (phone)
  final String baseUrl;

  /// returns the logged-in token (Sanctum / Bearer)
  final Future<String?> Function() token;

  /// any other header your API needs (client account, etc.)
  final Map<String, String>? extraHeaders;

  /// sent with every request, e.g. {'userId': '12'} (the mobile API knows the user by userId)
  final Map<String, String>? params;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final t = await token();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
      ...?extraHeaders,
    };
    var uri = Uri.parse('$baseUrl$path');
    if (params != null && params!.isNotEmpty)
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params!});
    final enc = body == null ? null : jsonEncode(body);
    final http.Response r;
    switch (method) {
      case 'PUT':
        r = await http.put(uri, headers: headers, body: enc);
        break;
      case 'POST':
        r = await http.post(uri, headers: headers, body: enc);
        break;
      default:
        r = await http.get(uri, headers: headers);
    }
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 400) {
      var msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Request failed (${r.statusCode}).';
      if (data is Map &&
          data['errors'] is Map &&
          (data['errors'] as Map).isNotEmpty) {
        final first = (data['errors'] as Map).values.first;
        msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
      }
      throw HrApiException(msg);
    }
    return data;
  }
}

/// for the menu: show "My profile" only when this is true
Future<bool> isStaffLogin(HrApi api) async {
  try {
    final r = await api.get('/hr/my-profile');
    return r is Map && _on(r['is_staff']);
  } catch (_) {
    return false;
  }
}

/* =========================================================
   look — same palette as the client Profile screen
   ========================================================= */
const _bgC = Color(0xFFF4F6FB);
const _card = Colors.white;
const _panel2 = Color(0xFFF1F5F9);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _line = Color(0xFFE2E8F0);
const _field = Color(0xFFDBE2EA);
const _indigo = Color(0xFF4F46E5);
const _red = Color(0xFFDC2626);

ThemeData staffTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _indigo,
    primary: _indigo,
    onPrimary: Colors.white,
    surface: _card,
    onSurface: _ink,
  ),
  scaffoldBackgroundColor: _bgC,
  appBarTheme: const AppBarTheme(
    backgroundColor: _bgC,
    surfaceTintColor: _bgC,
    foregroundColor: _ink,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: _ink,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  ),
  dividerColor: _line,
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: _card,
    hintStyle: const TextStyle(color: _faint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _field),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _field),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _indigo, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
  ),
);

/* =========================================================
   helpers
   ========================================================= */
String _s(dynamic v) => v == null ? '' : '$v';
bool _on(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
double _num(dynamic v) => double.tryParse(_s(v)) ?? 0;
String _n(dynamic v) {
  final d = _num(v);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

String _p(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_p(d.month)}-${_p(d.day)}';
String _key(dynamic v) {
  final s = _s(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

const _mon = [
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
const _monLong = [
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
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _week = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _fmtDate(dynamic v) {
  final d = DateTime.tryParse(_key(v));
  return d == null ? '—' : '${_mon[d.month - 1]} ${d.day}, ${d.year}';
}

/// "17:00", "17:00:00", "2026-11-05 17:00:00" → 5:00 PM
String _t12(dynamic v) {
  var s = _s(v);
  if (s.contains(' ')) s = s.split(' ').last;
  if (s.contains('T')) s = s.split('T').last;
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return '—';
  final h = int.parse(m.group(1)!);
  return '${(h + 11) % 12 + 1}:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
}

String _mins(dynamic v) {
  final m = _num(v).round();
  final h = m ~/ 60, r = m % 60;
  if (h == 0) return '${r}m';
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

DateTime _todayPH() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime(n.year, n.month, n.day);
}

String _initials(String name) => name
    .split(RegExp(r'[\s,]+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0])
    .join()
    .toUpperCase();

String _msg(dynamic r, String fallback) {
  final m = r is Map ? _s(r['message']) : '';
  return m.isEmpty ? fallback : m;
}

Widget _status(dynamic s) {
  final v = _s(s).toLowerCase();
  final MaterialColor c = switch (v) {
    'approved' => Colors.green,
    'pending' => Colors.orange,
    'rejected' || 'declined' || 'disapproved' => Colors.red,
    _ => Colors.grey,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: c.withAlpha(45),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      v.isEmpty ? '—' : v[0].toUpperCase() + v.substring(1),
      style: TextStyle(
        color: c.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _blank(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 32),
  child: Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _muted),
    ),
  ),
);

InputDecoration _dec(String label) => InputDecoration(labelText: label);

/* =========================================================
   fields (same names as the web form; a field shows only when the server sends it)
   ========================================================= */
enum _Kind { text, date, select, lookup }

class _F {
  const _F(
    this.key,
    this.label, {
    this.kind = _Kind.text,
    this.options = const [],
    this.required = false,
    this.keyboard,
    this.list,
    this.place,
    this.parent,
  });
  final String key, label;
  final _Kind kind;
  final List<String> options;
  final bool required;
  final TextInputType? keyboard;

  /// lookup: the list in /hr/employee-lookups (civil_statuses, religions, citizenships, provinces)
  final String? list;

  /// lookup: GET /hr/places/{place}?parent=  (cities · barangays)
  final String? place;

  /// lookup with place: the field that is the parent (province_id → cities, city_id → barangays); null = all
  final String? parent;
}

// the fields ProfileController lets the employee change (SELF_EDIT) — same lists as the web employee form
const _personal = [
  _F('last_name', 'Last name', required: true),
  _F('first_name', 'First name', required: true),
  _F('middle_name', 'Middle name'),
  _F('suffix', 'Suffix'),
  _F('birthdate', 'Birthdate', kind: _Kind.date),
  _F('gender', 'Gender', kind: _Kind.select, options: ['Male', 'Female']),
  _F('civ_stat_id', 'Civil status', kind: _Kind.lookup, list: 'civil_statuses'),
  _F('citizenship_id', 'Citizenship', kind: _Kind.lookup, list: 'citizenships'),
  _F('religion_id', 'Religion', kind: _Kind.lookup, list: 'religions'),
  _F('birth_place_id', 'Birth place', kind: _Kind.lookup, place: 'cities'),
];

const _contact = [
  _F('phone_num', 'Mobile number', keyboard: TextInputType.phone),
  _F('tell_num', 'Telephone number', keyboard: TextInputType.phone),
  _F('email_address', 'Email', keyboard: TextInputType.emailAddress),
  _F('street', 'Street / house no.'),
  _F('province_id', 'Province', kind: _Kind.lookup, list: 'provinces'),
  _F(
    'city_id',
    'City / municipality',
    kind: _Kind.lookup,
    place: 'cities',
    parent: 'province_id',
  ),
  _F(
    'brgy_id',
    'Barangay',
    kind: _Kind.lookup,
    place: 'barangays',
    parent: 'city_id',
  ),
];

/* =========================================================
   My profile
   ========================================================= */
/// staff "My profile" (route /myProfile) — the client profile stays in profile_screen.dart
class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key, required this.api, this.drawer});
  final HrApi api;

  /// your AppDrawer, so the menu stays available (the screen is opened with pushReplacementNamed)
  final Widget? drawer;

  @override
  Widget build(BuildContext context) => Theme(
    data: staffTheme(),
    child: _StaffProfile(api: api, drawer: drawer),
  );
}

class _StaffProfile extends StatefulWidget {
  const _StaffProfile({required this.api, this.drawer});
  final HrApi api;
  final Widget? drawer;

  @override
  State<_StaffProfile> createState() => _StaffProfileState();
}

class _StaffProfileState extends State<_StaffProfile> {
  Map<String, dynamic>? _data;
  Map<String, dynamic> _lk = {};
  String? _error;
  bool _loading = true, _saving = false;
  final Map<String, String> _form = {}, _saved = {};
  final Map<String, TextEditingController> _ctrl = {};
  // photo: picked here, sent only when "Save" is tapped
  bool _photoChanged = false;
  String? _pending; // data URL · null = remove
  Uint8List? _pendingBytes;

  HrApi get api => widget.api;

  // the section page that is open (Personal, Contact …) rebuilds together with this screen
  StateSetter? _sub;
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sub?.call(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final out = <String, dynamic>{};
    for (final path in ['/hr/lookups', '/hr/employee-lookups']) {
      try {
        final r = await api.get(path);
        if (r is Map) out.addAll(Map<String, dynamic>.from(r));
      } catch (_) {}
    }
    if (mounted) setState(() => _lk = out);
  }

  // cities / barangays by parent: 'cities:25' → rows (loaded once)
  final Map<String, List> _places = {};
  final Set<String> _placesLoading = {};

  Future<void> _loadPlaces(String kind, String parent) async {
    final key = '$kind:$parent';
    if (!_placesLoading.add(key)) return;
    try {
      final r = await api.get(
        '/hr/places/$kind?parent=${Uri.encodeQueryComponent(parent)}',
      );
      if (mounted) setState(() => _places[key] = r is List ? r : const []);
    } catch (_) {
      if (mounted) setState(() => _places[key] = const []);
    }
  }

  Future<void> _load() async {
    try {
      final r = await api.get('/hr/my-profile');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(r as Map);
        _error = null;
        _loading = false;
      });
      _fillForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _profile =>
      Map<String, dynamic>.from((_data?['profile'] as Map?) ?? {});
  List<_F> _present(List<_F> fs) =>
      fs.where((f) => f.required || _profile.containsKey(f.key)).toList();
  List<_F> get _editable => [..._present(_personal), ..._present(_contact)];

  String _norm(_F f, dynamic v) => f.kind == _Kind.date ? _key(v) : _s(v);

  void _fillForm() {
    final p = _profile;
    _saved
      ..clear()
      ..addEntries(_editable.map((f) => MapEntry(f.key, _norm(f, p[f.key]))));
    _form
      ..clear()
      ..addAll(_saved);
    for (final f in _editable) {
      (_ctrl[f.key] ??= TextEditingController()).text = _form[f.key] ?? '';
    }
    setState(() {});
  }

  bool _changed(List<_F> fs) =>
      _present(fs).any((f) => (_form[f.key] ?? '') != (_saved[f.key] ?? ''));
  bool get _dirty => _changed(_personal) || _changed(_contact);
  bool get _nameOk =>
      (_form['last_name'] ?? '').trim().isNotEmpty &&
      (_form['first_name'] ?? '').trim().isNotEmpty;

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  void _discard() {
    setState(() {
      _form
        ..clear()
        ..addAll(_saved);
      for (final e in _ctrl.entries) {
        e.value.text = _form[e.key] ?? '';
      }
      _photoChanged = false;
      _pending = null;
      _pendingBytes = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final msgs = <String>[];
    try {
      if (_dirty) {
        final body = {
          for (final f in _editable)
            f.key: (_form[f.key] ?? '').trim().isEmpty
                ? null
                : _form[f.key]!.trim(),
        };
        msgs.add(_msg(await api.put('/hr/my-profile', body), ''));
      }
      if (_photoChanged) {
        msgs.add(
          _msg(await api.post('/hr/my-profile/photo', {'photo': _pending}), ''),
        );
        _photoChanged = false;
        _pending = null;
        _pendingBytes = null;
      }
      final m = msgs.where((x) => x.isNotEmpty).join(' ');
      _toast(m.isEmpty ? 'Saved.' : m);
      await _load();
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /* ---------- photo ---------- */
  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final png = x.path.toLowerCase().endsWith('.png');
      setState(() {
        _pendingBytes = bytes;
        _pending =
            'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
        _photoChanged = true;
      });
    } catch (_) {
      _toast("This image can't be read.", error: true);
    }
  }

  String get _photoUrl => _s(_data?['photo_url']);

  ImageProvider? get _shownImage {
    if (_photoChanged)
      return _pendingBytes == null ? null : MemoryImage(_pendingBytes!);
    return _photoUrl.isEmpty ? null : NetworkImage(_photoUrl);
  }

  void _photoMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(c);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(c);
                _pick(ImageSource.camera);
              },
            ),
            if (_shownImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(c);
                  setState(() {
                    _photoChanged = _photoUrl
                        .isNotEmpty; // nothing saved yet → just drop the new pick
                    _pending = null;
                    _pendingBytes = null;
                  });
                },
              ),
            if (_photoChanged)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Undo photo change'),
                onTap: () {
                  Navigator.pop(c);
                  setState(() {
                    _photoChanged = false;
                    _pending = null;
                    _pendingBytes = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// rows {id, label} of a lookup field · null = still loading · [] = nothing to pick yet
  List<Map<String, String>>? _rowsOf(_F f) {
    List? list;
    if (f.place != null) {
      final parent = f.parent == null ? 'all' : (_form[f.parent!] ?? '');
      if (parent.isEmpty) return const [];
      list = _places['${f.place}:$parent'];
      if (list == null) {
        _loadPlaces(f.place!, parent);
        return null;
      }
    } else {
      final l = _lk[f.list];
      if (l is! List) return _lk.isEmpty ? null : const [];
      list = l;
    }
    return list
        .whereType<Map>()
        .map(
          (x) => {
            'id': _s(x['value'] ?? x['id']),
            'label': _s(x['label'] ?? x['name'] ?? x['value'] ?? x['id']),
          },
        )
        .toList();
  }

  /// searchable list, same as the client Profile picker
  Future<String?> _pickFrom(
    String title,
    List<Map<String, String>> rows,
    String current, {
    bool allowEmpty = true,
  }) {
    final options = [
      if (allowEmpty) {'id': '', 'label': '—'},
      ...rows,
    ];
    var q = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final list = q.isEmpty
              ? options
              : options
                    .where(
                      (o) =>
                          o['label']!.toLowerCase().contains(q.toLowerCase()),
                    )
                    .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(c).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(c).size.height * .7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(c),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: options.length > 12,
                        onChanged: (v) => setSheet(() => q = v),
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _faint,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: _bgC,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(
                              child: Text(
                                'No match',
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final o = list[i];
                                final on = o['id'] == current;
                                return ListTile(
                                  dense: true,
                                  onTap: () => Navigator.pop(c, o['id']),
                                  title: Text(
                                    o['label']!,
                                    style: TextStyle(
                                      color: on ? _indigo : _ink,
                                      fontWeight: on
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: on
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: _indigo,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _label(String listKey, dynamic id) {
    final l = _lk[listKey];
    if (l is! List || id == null) return null;
    for (final x in l) {
      if (x is Map && '${x['value'] ?? x['id']}' == '$id') {
        final t = _s(x['label'] ?? x['name'] ?? x['description']);
        return t.isEmpty ? null : t;
      }
    }
    return null;
  }

  /* ---------- build ---------- */
  @override
  Widget build(BuildContext context) {
    Widget plain(Widget body) => Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      drawer: widget.drawer,
      body: body,
    );

    if (_loading)
      return plain(const Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return plain(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Couldn't load your profile.\n$_error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final d = _data!;
    if (!_on(d['is_staff']))
      return plain(_blank('My profile is only for staff logins.'));
    if (!_on(d['linked'])) {
      return plain(
        _blank(
          '${_s(d['login_name']).isEmpty ? 'Your login' : _s(d['login_name'])}\n\n'
          'Your login is not linked to an employee record yet, so there is no profile to show.',
        ),
      );
    }

    final emp = Map<String, dynamic>.from((d['employee'] as Map?) ?? {});
    final designation = _label('designations', _profile['designation_id']);
    final company = _label('companies', _profile['company_caid']);
    final shift = d['shift'] is Map
        ? Map<String, dynamic>.from(d['shift'] as Map)
        : null;
    final credits = (d['leave_credits'] as List?) ?? const [];

    Tab tab(String label, {bool dot = false, int? count}) => Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count > 0)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _indigo.withAlpha(25),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _indigo,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (dot)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: CircleAvatar(radius: 3.5, backgroundColor: Colors.orange),
            ),
        ],
      ),
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        drawer: widget.drawer,
        body: Column(
          children: [
            _profileCard(
              _s(emp['full_name']),
              designation,
              company,
              _s(_profile['email_address']),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: _card,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    builder: (_) => Theme(
                      data: Theme.of(context),
                      child: _ChangePassword(api: api),
                    ),
                  ),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _indigo,
                    backgroundColor: _card,
                    side: const BorderSide(color: _field),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // tabs like the web: Personal · Contact · Work · Shift · Banks · Leave & OT
            Container(
              color: _card,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelColor: _indigo,
                unselectedLabelColor: _muted,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                indicatorColor: _indigo,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: _line,
                tabs: [
                  tab('Personal', dot: _changed(_personal)),
                  tab('Contact', dot: _changed(_contact)),
                  tab('Shift'),
                  tab('Leave & OT'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _editTab(
                    _personal,
                    'Name, birth and civil details · you can update these',
                  ),
                  _editTab(
                    _contact,
                    'How to reach you and where you live · you can update these',
                  ),
                  _shiftTab(shift, _on(d['shift_is_default'])),
                  _LeaveOt(
                    api: api,
                    shift: shift,
                    credits: credits,
                    lookups: _lk,
                    onChanged: _load,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: (_dirty || _photoChanged) ? _saveBar() : null,
      ),
    );
  }

  String _titleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// the profile card on top: rounded, blue gradient, photo with a white ring
  Widget _profileCard(
    String name,
    String? designation,
    String? company,
    String email,
  ) {
    final role = [
      designation,
      company,
    ].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _indigo.withAlpha(70),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // soft circles in the background
            Positioned(right: -30, top: -40, child: _bubble(140, 28)),
            Positioned(right: 60, bottom: -50, child: _bubble(110, 18)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _photo(size: 84),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleCase(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            role,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(215),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_photoChanged) ...[
                          const SizedBox(height: 6),
                          Text(
                            _pending != null
                                ? 'New photo · not saved yet'
                                : 'Photo will be removed',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
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

  Widget _bubble(double size, int alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withAlpha(alpha),
    ),
  );

  /// round photo with a white ring and the camera badge (tap = change)
  Widget _photo({required double size}) {
    final img = _shownImage;
    final name = _s((_data?['employee'] as Map?)?['full_name']);
    return GestureDetector(
      onTap: _saving ? null : _photoMenu,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: size / 2 - 3,
                backgroundColor: const Color(0xFFE0E7FF),
                backgroundImage: img,
                child: img == null
                    ? Text(
                        _initials(name),
                        style: TextStyle(
                          color: _indigo,
                          fontSize: size * .3,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _line),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: _indigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editTab(List<_F> fs, String sub) {
    final list = _present(fs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            sub,
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
        ),
        if (list.isEmpty)
          _blank('Nothing to edit here.')
        else
          _panel([
            for (final f in list) _input(f),
            if (list.any((f) => f.required))
              const Text(
                '* Required',
                style: TextStyle(color: _faint, fontSize: 11.5),
              ),
          ]),
      ],
    );
  }

  /// white panel with rounded edge (same as the client Profile)
  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  /// label above the field, red * when required
  Widget _lbl(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: t,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _red),
            ),
        ],
      ),
    ),
  );

  /// a box that opens a picker / date (same look as a text field)
  Widget _boxButton(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool placeholder = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: onTap == null ? _panel2 : _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _field),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: placeholder ? _faint : _ink,
                fontSize: 14.5,
              ),
            ),
          ),
          Icon(icon, color: _faint, size: 18),
        ],
      ),
    ),
  );

  Widget _input(_F f) {
    final v = _form[f.key] ?? '';
    Widget wrap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lbl(f.label, required: f.required),
          child,
        ],
      ),
    );

    switch (f.kind) {
      case _Kind.text:
        return wrap(
          TextField(
            controller: _ctrl[f.key],
            enabled: !_saving,
            keyboardType: f.keyboard,
            style: const TextStyle(color: _ink, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: f.key == 'suffix' ? 'Jr., Sr., III…' : null,
            ),
            onChanged: (x) => setState(() => _form[f.key] = x),
          ),
        );

      case _Kind.select: // gender: Male / Female switch
        final upper = v.isNotEmpty && v == v.toUpperCase();
        return wrap(
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _panel2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final o in f.options)
                  Expanded(
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () => setState(
                              () => _form[f.key] = upper ? o.toUpperCase() : o,
                            ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: v.toUpperCase() == o.toUpperCase()
                              ? _card
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: v.toUpperCase() == o.toUpperCase()
                              ? [
                                  BoxShadow(
                                    color: _ink.withAlpha(20),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          o,
                          style: TextStyle(
                            color: v.toUpperCase() == o.toUpperCase()
                                ? _indigo
                                : _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

      case _Kind.date:
        return wrap(
          Row(
            children: [
              Expanded(
                child: _boxButton(
                  v.isEmpty ? '—' : _fmtDate(v),
                  Icons.event_rounded,
                  _saving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(v) ?? DateTime(1990),
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null)
                            setState(() => _form[f.key] = _ymd(picked));
                        },
                  placeholder: v.isEmpty,
                ),
              ),
              if (v.isNotEmpty && !_saving)
                IconButton(
                  onPressed: () => setState(() => _form[f.key] = ''),
                  icon: const Icon(Icons.close_rounded, color: _faint),
                ),
            ],
          ),
        );

      case _Kind.lookup:
        final rows = _rowsOf(f);
        final needParent = f.parent != null && (_form[f.parent!] ?? '').isEmpty;
        final shownLabel = v.isEmpty
            ? ''
            : (rows?.firstWhere(
                    (r) => r['id'] == v,
                    orElse: () => {'id': v, 'label': ''},
                  )['label'] ??
                  '');
        final text = shownLabel.isNotEmpty
            ? shownLabel
            : needParent
            ? 'Pick the ${f.parent == 'province_id' ? 'province' : 'city'} first'
            : (rows == null || v.isNotEmpty)
            ? 'Loading…'
            : '—';
        return wrap(
          _boxButton(
            text,
            Icons.expand_more_rounded,
            _saving || rows == null || rows.isEmpty
                ? null
                : () async {
                    final x = await _pickFrom(f.label, rows, v);
                    if (x == null || x == v) return;
                    setState(() {
                      _form[f.key] = x;
                      // a new province / city → pick the city / barangay again
                      if (f.key == 'province_id') {
                        _form['city_id'] = '';
                        _form['brgy_id'] = '';
                      }
                      if (f.key == 'city_id') _form['brgy_id'] = '';
                    });
                  },
            placeholder: shownLabel.isEmpty,
          ),
        );
    }
  }

  Widget _viewOnly(String title, String sub) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(sub, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'View only',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _shiftTab(Map<String, dynamic>? s, bool isDefault) {
    if (s == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _viewOnly('No shift', ''),
          _blank('No shift set yet. HR sets it.'),
        ],
      );
    }
    final work = _s(s['work_days']).split(',');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _viewOnly(
          _s(s['name']).isEmpty ? 'Shift' : _s(s['name']),
          isDefault ? 'You follow the default shift' : 'Your own shift',
        ),
        const SizedBox(height: 8),
        _row('Time in', _t12(s['time_in'])),
        _row(
          'Break',
          _s(s['break_in']).isEmpty
              ? 'No break'
              : '${_t12(s['break_in'])} – ${_t12(s['break_out'])}',
        ),
        _row(
          'Time out',
          '${_t12(s['time_out'])}${_on(s['is_overnight']) ? ' (+1 day)' : ''}',
        ),
        _row('Paid hours', '${_n(s['paid_hours'])} h / day'),
        _row('Grace period', '${_n(s['grace_minutes'])} min late allowance'),
        _row('Overnight', _on(s['is_overnight']) ? 'Yes' : 'No'),
        const SizedBox(height: 8),
        const Text('Work days', style: TextStyle(color: _muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 7; i++)
              Chip(
                label: Text(_days[i]),
                visualDensity: VisualDensity.compact,
                backgroundColor: work.contains('${i + 1}')
                    ? Theme.of(context).colorScheme.primaryContainer
                    : _panel2,
              ),
          ],
        ),
      ],
    );
  }

  Widget _saveBar() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_nameOk)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Last name and first name are required.',
                style: TextStyle(color: _red, fontSize: 12.5),
              ),
            ),
          Row(
            children: [
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _saving ? null : _discard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: const BorderSide(color: _field),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving || !_nameOk ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE0E7FF),
                      disabledForegroundColor: const Color(0xFF818CF8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : 'Save changes${_photoChanged && !_dirty ? ' (photo)' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/* =========================================================
   Leave & OT: calendar + my requests
   ========================================================= */
class _Day {
  final holidays = <Map>[];
  final leaves = <Map>[];
  final ot = <Map>[];
  Map? att;
}

class _LeaveOt extends StatefulWidget {
  const _LeaveOt({
    required this.api,
    required this.shift,
    required this.credits,
    required this.lookups,
    required this.onChanged,
  });
  final HrApi api;
  final Map<String, dynamic>? shift;
  final List credits;
  final Map<String, dynamic> lookups;
  final VoidCallback onChanged;

  @override
  State<_LeaveOt> createState() => _LeaveOtState();
}

class _LeaveOtState extends State<_LeaveOt> with AutomaticKeepAliveClientMixin {
  final DateTime _today = _todayPH();
  late DateTime _month = DateTime(_today.year, _today.month);
  Map _cal = {};
  Map? _reqs;
  int? _reqYear;
  String _list = 'leave';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCal();
    _loadReqs();
  }

  Future<void> _loadReqs() async {
    final y = _month.year;
    try {
      final r = await widget.api.get('/hr/my-requests?year=$y');
      if (mounted) {
        setState(() {
          _reqs = r is Map ? r : {};
          _reqYear = y;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reqs = {'overtime': [], 'leaves': []});
    }
  }

  Future<void> _loadCal() async {
    final m = '${_month.year}-${_p(_month.month)}';
    try {
      final r = await widget.api.get('/hr/my-calendar?month=$m');
      if (mounted) setState(() => _cal = r is Map ? r : {});
    } catch (_) {
      if (mounted) setState(() => _cal = {});
    }
  }

  void _go(int n) {
    setState(() => _month = DateTime(_month.year, _month.month + n));
    _loadCal();
    if (_month.year != _reqYear) {
      setState(() => _reqs = null);
      _loadReqs();
    }
  }

  List<Map> _rows(String k) =>
      ((_reqs?[k] as List?) ?? const []).whereType<Map>().toList();

  Map<String, _Day> get _byDate {
    final m = <String, _Day>{};
    _Day at(String k) => m.putIfAbsent(k, () => _Day());
    for (final h
        in ((_cal['holidays'] as List?) ?? const []).whereType<Map>()) {
      at(_key(h['date'])).holidays.add(h);
    }
    for (final a
        in ((_cal['attendance'] as List?) ?? const []).whereType<Map>()) {
      at(_key(a['date'])).att = a;
    }
    for (final o in _rows(
      'overtime',
    ).where((o) => o['status'] != 'cancelled')) {
      at(_key(o['work_date'])).ot.add(o);
    }
    for (final l in _rows('leaves').where((l) => l['status'] != 'cancelled')) {
      final from = DateTime.tryParse(_key(l['date_from']));
      final to = DateTime.tryParse(_key(l['date_to']));
      if (from == null || to == null) continue;
      for (
        var d = from;
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        at(_ymd(d)).leaves.add(l);
      }
    }
    return m;
  }

  List<String> get _workDays =>
      _s(widget.shift?['work_days'] ?? '1,2,3,4,5,6').split(',');

  void _done(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _loadReqs();
    _loadCal();
    widget.onChanged();
  }

  Future<void> _file(String kind, DateTime date) async {
    final theme = Theme.of(context);
    final msg = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: theme,
          child: kind == 'leave'
              ? _LeaveForm(
                  api: widget.api,
                  date: date,
                  credits: widget.credits,
                  lookups: widget.lookups,
                )
              : _OvertimeForm(
                  api: widget.api,
                  date: date,
                  shift: widget.shift,
                  lookups: widget.lookups,
                ),
        ),
      ),
    );
    if (msg != null) _done(msg);
  }

  Future<void> _cancel(String kind, Map r) async {
    final desc = kind == 'leave'
        ? '${_s(r['leave_type']?['code']).isEmpty ? 'Leave' : r['leave_type']['code']} · ${_range(r)} · ${_n(r['days'])} day(s)'
        : '${_fmtDate(r['work_date'])} · ${_t12(r['time_start'])} – ${_t12(r['time_end'])}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cancel this ${kind == 'leave' ? 'leave' : 'overtime'}?'),
        content: Text(desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _done(
        _msg(
          await widget.api.put('/hr/my-requests/$kind/${r['id']}/cancel'),
          'Request cancelled.',
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
    }
  }

  String _range(Map r) => _key(r['date_from']) == _key(r['date_to'])
      ? _fmtDate(r['date_from'])
      : '${_fmtDate(r['date_from'])} – ${_fmtDate(r['date_to'])}';

  void _openDay(DateTime d, _Day? info) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmtDate(_ymd(d)),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (info != null) ...[
                for (final h in info.holidays)
                  _infoLine(Colors.purple, _s(h['name'])),
                for (final l in info.leaves)
                  _infoLine(
                    Colors.blue,
                    '${_s(l['leave_type']?['code']).isEmpty ? 'Leave' : l['leave_type']['code']}'
                    '${_on(l['is_half_day']) ? ' ½ ${_s(l['half_day_part'])}' : ''} · ${_s(l['status'])}',
                  ),
                for (final o in info.ot)
                  _infoLine(
                    Colors.orange,
                    'OT ${_mins(o['minutes'])} · ${_s(o['status'])}',
                  ),
                if (info.att != null && _s(info.att!['time_in']).isNotEmpty)
                  _infoLine(
                    Colors.green,
                    'Time in ${_t12(info.att!['time_in'])}'
                    '${_num(info.att!['late_minutes']) > 0 ? ' · late ${_n(info.att!['late_minutes'])}m' : ''}',
                  ),
                if (info.att != null &&
                    _s(info.att!['time_in']).isEmpty &&
                    info.att!['status'] == 'absent')
                  _infoLine(Colors.red, 'Absent'),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _file('overtime', d);
                      },
                      child: const Text('File overtime'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _file('leave', d);
                      },
                      child: const Text('File leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoLine(Color c, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final byDate = _byDate;
    final first = DateTime(_month.year, _month.month, 1);
    final start = DateTime(
      first.year,
      first.month,
      1 - first.weekday % 7,
    ); // Sunday first
    final cells = List.generate(
      42,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
    final pending =
        _rows('leaves').where((l) => l['status'] == 'pending').length +
        _rows('overtime').where((o) => o['status'] == 'pending').length;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadCal(), _loadReqs()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tap a day to file a leave or overtime${pending > 0 ? ' · $pending waiting for approval' : ''}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _file('overtime', _today),
                  child: const Text('File overtime'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _file('leave', _today),
                  child: const Text('File leave'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // calendar
          Row(
            children: [
              IconButton(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monLong[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _go(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (_month.year != _today.year || _month.month != _today.month)
            Center(
              child: TextButton(
                onPressed: () => _go(
                  (_today.year - _month.year) * 12 +
                      _today.month -
                      _month.month,
                ),
                child: const Text('Today'),
              ),
            ),
          Row(
            children: [
              for (final w in _week)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.78,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: [for (final d in cells) _cell(d, byDate[_ymd(d)], cs)],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legend(Colors.blue, 'Leave'),
              _legend(Colors.orange, 'Overtime'),
              _legend(Colors.purple, 'Holiday'),
              _legend(Colors.green, 'Worked'),
              _legend(Colors.red, 'Absent / late'),
            ],
          ),
          const SizedBox(height: 18),

          // my requests
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'leave',
                label: Text('My leave (${_rows('leaves').length})'),
              ),
              ButtonSegment(
                value: 'overtime',
                label: Text('My overtime (${_rows('overtime').length})'),
              ),
            ],
            selected: {_list},
            onSelectionChanged: (s) => setState(() => _list = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            '${_month.year}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (_reqs == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_list == 'leave') ...[
            if (_rows('leaves').isEmpty)
              _blank('No leave filed in ${_month.year}.'),
            for (final r in _rows('leaves')) _leaveCard(r),
          ] else ...[
            if (_rows('overtime').isEmpty)
              _blank('No overtime filed in ${_month.year}.'),
            for (final r in _rows('overtime')) _otCard(r),
          ],
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _cell(DateTime d, _Day? info, ColorScheme cs) {
    final out = d.month != _month.month;
    final isToday = _ymd(d) == _ymd(_today);
    final rest = !_workDays.contains('${d.weekday}'); // 1 = Mon … 7 = Sun
    final holiday = info?.holidays.isNotEmpty == true;
    final att = info?.att;
    final late = att != null && _num(att['late_minutes']) > 0;
    final absent =
        att != null && _s(att['time_in']).isEmpty && att['status'] == 'absent';
    final dots = <Color>[
      if (info?.leaves.isNotEmpty == true) Colors.blue,
      if (info?.ot.isNotEmpty == true) Colors.orange,
      if (holiday) Colors.purple,
      if (att != null && _s(att['time_in']).isNotEmpty)
        late ? Colors.red : Colors.green,
      if (absent) Colors.red,
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDay(d, info),
      child: Container(
        decoration: BoxDecoration(
          color: holiday
              ? Colors.purple.withAlpha(40)
              : rest
              ? _panel2
              : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday ? cs.primary : _line,
            width: isToday ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          children: [
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: out ? _faint : null,
              ),
            ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final c in dots)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: out ? c.withAlpha(90) : c,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _decided(Map r) => r['status'] == 'pending'
      ? const Text(
          'Waiting for approval',
          style: TextStyle(color: _muted, fontSize: 12),
        )
      : Text(
          '${_fmtDate(r['approved_at'])}${_s(r['decided_by']).isEmpty ? '' : ' · by ${_s(r['decided_by'])}'}',
          style: const TextStyle(color: _muted, fontSize: 12),
        );

  Widget _reqCard({
    required Widget title,
    required List<Widget> lines,
    required Map r,
    required String kind,
  }) => Card(
    color: _card,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              _status(r['status']),
            ],
          ),
          const SizedBox(height: 4),
          ...lines,
          _decided(r),
          if (_s(r['approver_remarks']).isNotEmpty)
            Text(
              'Remarks: ${_s(r['approver_remarks'])}',
              style: const TextStyle(fontSize: 12),
            ),
          if (r['status'] == 'pending')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancel(kind, r),
                child: const Text('Cancel'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _leaveCard(Map r) {
    final t = r['leave_type'] is Map ? r['leave_type'] as Map : const {};
    return _reqCard(
      kind: 'leave',
      r: r,
      title: Text(
        '${_s(t['code'])}${_s(t['name']).isEmpty ? '' : ' · ${_s(t['name'])}'}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      lines: [
        Text(
          '${_range(r)} · ${_n(r['days'])} day(s)${_on(r['is_half_day']) ? ' (${_s(r['half_day_part']).isEmpty ? 'half' : _s(r['half_day_part'])})' : ''}',
        ),
        if (_s(r['reason']).isNotEmpty)
          Text(_s(r['reason']), style: const TextStyle(color: _muted)),
      ],
    );
  }

  Widget _otCard(Map r) => _reqCard(
    kind: 'overtime',
    r: r,
    title: Text(
      _fmtDate(r['work_date']),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    lines: [
      Text(
        '${_t12(r['time_start'])} – ${_t12(r['time_end'])} · ${_mins(r['minutes'])}',
      ),
      if (_s(r['reason']).isNotEmpty)
        Text(_s(r['reason']), style: const TextStyle(color: _muted)),
    ],
  );
}

/* =========================================================
   Change password — same as the web ChangePasswordModal
   PUT /me/password { current_password, password, password_confirmation }
   ========================================================= */
const _pwRules = [
  ['8+ characters', 'len'],
  ['Upper & lower case', 'case'],
  ['A number', 'num'],
  ['A symbol', 'sym'],
];
bool _pwRule(String k, String p) => switch (k) {
  'len' => p.length >= 8,
  'case' => RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p),
  'num' => RegExp(r'\d').hasMatch(p),
  _ => RegExp(r'[^A-Za-z0-9]').hasMatch(p),
};

/// null = empty · 0 too short · 1 weak · 2 fair · 3 good · 4 strong
int? _pwLevel(String p) {
  if (p.isEmpty) return null;
  if (p.length < 8) return 0;
  final n = _pwRules.where((r) => _pwRule(r[1], p)).length;
  return n < 1 ? 1 : n;
}

class _ChangePassword extends StatefulWidget {
  const _ChangePassword({required this.api});
  final HrApi api;

  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final _cur = TextEditingController(),
      _next = TextEditingController(),
      _again = TextEditingController();
  final _show = <String, bool>{};
  final _err = <String, String>{};
  bool _saving = false;

  @override
  void dispose() {
    _cur.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final e = <String, String>{};
    if (_cur.text.isEmpty) e['current'] = 'Type your current password.';
    if (_next.text.length < 8) {
      e['next'] = 'The new password needs at least 8 characters.';
    } else if (_next.text == _cur.text) {
      e['next'] = 'Use a password different from the current one.';
    }
    if (e['next'] == null && _again.text != _next.text)
      e['again'] = "The new passwords don't match.";
    setState(
      () => _err
        ..clear()
        ..addAll(e),
    );
    if (e.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final r = await widget.api.put('/me/password', {
        'current_password': _cur.text,
        'password': _next.text,
        'password_confirmation': _again.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_msg(r, 'Password changed.'))));
    } catch (x) {
      final m = '$x';
      setState(() {
        _saving = false;
        _err[RegExp('current', caseSensitive: false).hasMatch(m)
                ? 'current'
                : RegExp('match', caseSensitive: false).hasMatch(m)
                ? 'again'
                : 'next'] =
            m;
      });
    }
  }

  Widget _pw(
    String k,
    String label,
    TextEditingController c, {
    String? hint,
    String? error,
    bool autofocus = false,
  }) {
    final show = _show[k] ?? false;
    final err = error ?? _err[k];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextField(
            controller: c,
            obscureText: !show,
            autofocus: autofocus,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_saving,
            style: const TextStyle(color: _ink, fontSize: 14.5),
            onChanged: (_) => setState(() => _err.remove(k)),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: _faint,
              ),
              suffixIcon: IconButton(
                tooltip: show ? 'Hide' : 'Show',
                icon: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: _faint,
                ),
                onPressed: () => setState(() => _show[k] = !show),
              ),
              enabledBorder: err != null && err.isNotEmpty
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _red),
                    )
                  : null,
            ),
          ),
          if (err != null && err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                err,
                style: const TextStyle(color: _red, fontSize: 12),
              ),
            )
          else if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _next.text;
    final level = _pwLevel(p);
    final matches = _again.text.isNotEmpty && _again.text == p;
    const labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    const tones = [
      _red,
      _red,
      Color(0xFFD97706),
      Color(0xFF16A34A),
      Color(0xFF059669),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Change password',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // intro
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: _indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep your account safe',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Confirm your current password, then choose a new one. Other devices using this login will be signed out.',
                            style: TextStyle(color: _muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _pw('current', 'Current password', _cur, autofocus: true),
              const Divider(height: 18, color: _line),
              _pw('next', 'New password', _next),
              // strength
              if (level != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (var i = 1; i <= 4; i++)
                        Expanded(
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i <= level ? tones[level] : _line,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        labels[level],
                        style: TextStyle(
                          color: tones[level],
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              // rules
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final r in _pwRules)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _pwRule(r[1], p)
                                  ? const Color(0xFF059669)
                                  : _panel2,
                              shape: BoxShape.circle,
                            ),
                            child: _pwRule(r[1], p)
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r[0],
                            style: TextStyle(
                              color: _pwRule(r[1], p) ? _ink : _muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              _pw(
                'again',
                'Confirm new password',
                _again,
                error:
                    _err['again'] ??
                    (_again.text.isNotEmpty && !matches
                        ? "Doesn't match yet."
                        : null),
                hint: matches ? '✓ Passwords match' : null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _muted,
                          side: const BorderSide(color: _field),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE0E7FF),
                          disabledForegroundColor: const Color(0xFF818CF8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Update password',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   date / time fields
   ========================================================= */
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.first,
  });
  final String label;
  final DateTime value;
  final DateTime? first;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final p = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: first ?? DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (p != null) onPick(p);
    },
    child: InputDecorator(
      decoration: _dec(label).copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(_fmtDate(_ymd(value))),
    ),
  );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
    this.hint,
  });
  final String label;
  final TimeOfDay value;
  final String? hint;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final p = await showTimePicker(context: context, initialTime: value);
      if (p != null) onPick(p);
    },
    child: InputDecorator(
      decoration: _dec(label).copyWith(
        helperText: hint,
        suffixIcon: const Icon(Icons.schedule, size: 18),
      ),
      child: Text(value.format(context)),
    ),
  );
}

Future<Map<String, dynamic>> _lookups(
  HrApi api,
  Map<String, dynamic> have,
) async {
  if (have.isNotEmpty) return have;
  try {
    final r = await api.get('/hr/lookups');
    return r is Map ? Map<String, dynamic>.from(r) : {};
  } catch (_) {
    return {};
  }
}

/* =========================================================
   File leave
   ========================================================= */
class _LeaveForm extends StatefulWidget {
  const _LeaveForm({
    required this.api,
    required this.date,
    required this.credits,
    required this.lookups,
  });
  final HrApi api;
  final DateTime date;
  final List credits;
  final Map<String, dynamic> lookups;

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  List<Map> _types = [];
  String? _type;
  late DateTime _from = widget.date, _to = widget.date;
  bool _half = false;
  String _part = 'AM';
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lookups(widget.api, widget.lookups).then((lk) {
      if (!mounted) return;
      setState(
        () => _types = ((lk['leave_types'] as List?) ?? const [])
            .whereType<Map>()
            .where((t) => _on(t['is_active']))
            .toList(),
      );
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Map? get _credit {
    for (final c in widget.credits.whereType<Map>()) {
      if ('${c['leave_type_id']}' == _type) return c;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await widget.api.post('/hr/leaves', {
        'leave_type_id': int.tryParse(_type!) ?? _type,
        'date_from': _ymd(_from),
        'date_to': _ymd(_half ? _from : _to),
        'is_half_day': _half,
        'half_day_part': _half ? _part : null,
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, _msg(r, 'Leave filed.'));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _credit;
    final ok = !_busy && _type != null && _reason.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('File leave')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: _dec('Leave type'),
            isExpanded: true,
            items: [
              for (final t in _types)
                DropdownMenuItem(
                  value: '${t['id']}',
                  child: Text(
                    '${_s(t['code'])} · ${_s(t['name'])}${_on(t['is_paid']) ? '' : ' (unpaid)'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
          if (_type != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Days left', c == null ? '—' : _n(c['remaining_days'])),
                _stat(
                  'Allowed',
                  c == null
                      ? '—'
                      : _n(_num(c['allowed_days']) + _num(c['carried_over'])),
                ),
                _stat('Used', c == null ? '—' : _n(c['used_days'])),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Half day'),
            value: _half,
            onChanged: (v) => setState(() => _half = v),
          ),
          _DateField(
            label: _half ? 'Date' : 'From',
            value: _from,
            onPick: (d) => setState(() {
              _from = d;
              if (_to.isBefore(d)) _to = d;
            }),
          ),
          const SizedBox(height: 12),
          if (_half)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'AM', label: Text('Morning (AM)')),
                ButtonSegment(value: 'PM', label: Text('Afternoon (PM)')),
              ],
              selected: {_part},
              onSelectionChanged: (s) => setState(() => _part = s.first),
            )
          else
            _DateField(
              label: 'To',
              value: _to,
              first: _from,
              onPick: (d) => setState(() => _to = d),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            decoration: _dec(
              'Reason',
            ).copyWith(hintText: 'e.g. Family event, check-up'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only your work days are counted. Rest days and holidays are skipped.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: ok ? _save : null,
            child: Text(_busy ? 'Filing…' : 'File leave'),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

/* =========================================================
   File overtime
   ========================================================= */
class _OvertimeForm extends StatefulWidget {
  const _OvertimeForm({
    required this.api,
    required this.date,
    required this.shift,
    required this.lookups,
  });
  final HrApi api;
  final DateTime date;
  final Map<String, dynamic>? shift;
  final Map<String, dynamic> lookups;

  @override
  State<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<_OvertimeForm> {
  List<Map> _rates = [];
  late DateTime _date = widget.date;
  late TimeOfDay _start, _end;
  String _rate = 'REG_OT';
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // starts when the shift ends, 2 hours by default
    final m = RegExp(
      r'(\d{1,2}):(\d{2})',
    ).firstMatch(_s(widget.shift?['time_out']));
    _start = m == null
        ? const TimeOfDay(hour: 17, minute: 0)
        : TimeOfDay(
            hour: int.parse(m.group(1)!),
            minute: int.parse(m.group(2)!),
          );
    _end = TimeOfDay(hour: (_start.hour + 2) % 24, minute: _start.minute);
    _lookups(widget.api, widget.lookups).then((lk) {
      if (!mounted) return;
      setState(() {
        _rates = ((lk['pay_rates'] as List?) ?? const [])
            .whereType<Map>()
            .where((r) => _on(r['is_active']) && _s(r['code']).contains('OT'))
            .toList();
        if (_rates.isNotEmpty && !_rates.any((r) => r['code'] == _rate))
          _rate = _s(_rates.first['code']);
      });
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _s0 => _start.hour * 60 + _start.minute;
  int get _e0 => _end.hour * 60 + _end.minute;
  bool get _nextDay => _e0 <= _s0;
  int get _minutes => _e0 - _s0 + (_nextDay ? 1440 : 0);
  String _hm(TimeOfDay t) => '${_p(t.hour)}:${_p(t.minute)}';

  Future<void> _save() async {
    setState(() => _busy = true);
    final day = _ymd(_date);
    final endDay = _nextDay
        ? _ymd(DateTime(_date.year, _date.month, _date.day + 1))
        : day;
    try {
      final r = await widget.api.post('/hr/overtime', {
        'work_date': day,
        'time_start': '$day ${_hm(_start)}:00',
        'time_end': '$endDay ${_hm(_end)}:00',
        'pay_rate_code': _rate,
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, _msg(r, 'Overtime filed.'));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = !_busy && _reason.text.trim().isNotEmpty && _minutes > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('File overtime')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DateField(
            label: 'Date',
            value: _date,
            onPick: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('rate:$_rate:${_rates.length}'),
            initialValue: _rate,
            decoration: _dec('Kind'),
            isExpanded: true,
            items: _rates.isEmpty
                ? const [
                    DropdownMenuItem(
                      value: 'REG_OT',
                      child: Text('Regular overtime'),
                    ),
                  ]
                : [
                    for (final r in _rates)
                      DropdownMenuItem(
                        value: _s(r['code']),
                        child: Text(
                          _s(r['description']).isEmpty
                              ? _s(r['code'])
                              : _s(r['description']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
            onChanged: (v) => setState(() => _rate = v ?? _rate),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Start',
                  value: _start,
                  onPick: (t) => setState(() => _start = t),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeField(
                  label: 'End',
                  value: _end,
                  hint: _nextDay ? 'Ends the next day' : null,
                  onPick: (t) => setState(() => _end = t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _panel2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Total', style: TextStyle(color: _muted)),
                const Spacer(),
                Text(
                  _mins(_minutes),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            decoration: _dec(
              'Reason',
            ).copyWith(hintText: 'e.g. Month-end closing'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your supervisor approves it. Approved overtime is paid in the payroll.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: ok ? _save : null,
            child: Text(_busy ? 'Filing…' : 'File overtime'),
          ),
        ),
      ),
    );
  }
}
