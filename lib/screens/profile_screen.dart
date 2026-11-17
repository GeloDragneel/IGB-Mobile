import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/api_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/navigation_drawer.dart';

/// Profile = the web Settings (same SettingsController through MobileController::profileSettings):
/// Profile · Contact · Address · Business Ownership · Classification & Compliance · Engagement ·
/// Valid IDs · Business Accounts, plus Language and Documents.

/* ---------- palette (same as the other screens) ---------- */
const _bg = Color(0xFFF4F6FB);
const _card = Colors.white;
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _line = Color(0xFFE2E8F0);
const _indigo = Color(0xFF4F46E5);
const _red = Color(0xFFDC2626);
const _green = Color(0xFF059669);

const _institutions = [
  'BIR',
  'SSS',
  'PHILHEALTH',
  'PAG-IBIG',
  'DTI',
  'SEC',
  "MAYOR'S PERMIT",
  'OTHERS',
];
const _clientFields = [
  'last_name',
  'first_name',
  'middle_name',
  'suffix',
  'gender',
  'birthdate',
  'civ_stat_id',
  'status_id',
  'phone_num',
  'tell_num',
  'email_address',
  'street',
  'province_id',
  'city_id',
  'brgy_id',
  'business_ownership_type_id',
  'business_ownership_type_detail_id',
  'classification_id',
  'industries_id',
  'date_of_engagement',
  'date_of_disengagement',
  'date_started',
  'date_registered',
];
const _dateFields = [
  'birthdate',
  'date_of_engagement',
  'date_of_disengagement',
  'date_started',
  'date_registered',
];

String _s(dynamic v) => v == null ? '' : '$v';
// "0000-00-00" (old system) or not a real date → empty
String _day(dynamic v) {
  final s = _s(v).length >= 10 ? _s(v).substring(0, 10) : '';
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) &&
          !s.startsWith('0000') &&
          DateTime.tryParse(s) != null
      ? s
      : '';
}

String _fmtTin(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.length > 9) d = d.substring(0, 9);
  return d.replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]}-');
}

/* =========================================================
   API (MobileController::profileSettings)
   ========================================================= */
class _Api {
  _Api(this.userId);
  final String userId;

  Future<dynamic> call(
    String action, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/profile_settings',
    ).replace(queryParameters: {'userId': userId, 'action': action, ...?query});
    final res = body == null
        ? await http.get(uri, headers: {'Accept': 'application/json'})
        : await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          );
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      throw 'Server error (${res.statusCode})';
    }
    if (res.statusCode >= 300)
      throw (data is Map ? data['message'] : null) ?? 'Error ${res.statusCode}';
    return data;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _Api api;
  Map<String, dynamic>? data; // /settings response
  Map<String, String> form = {}; // client form (same fields as the web)
  Set<String> compliance = {};
  String saved = '';
  String error = '';
  bool saving = false;
  List<Map<String, dynamic>> documents = [];

  @override
  void initState() {
    super.initState();
    api = _Api(Provider.of<AuthProvider>(context, listen: false).userId);
    _load();
    _fetchDocuments();
  }

  bool get _zh => AppLocalizations.of(context).locale.languageCode == 'zh';
  String _t(String en, String zh) => _zh ? zh : en;

  Map<String, dynamic> get L =>
      Map<String, dynamic>.from(data?['lookups'] ?? {});
  List<Map<String, dynamic>> _list(dynamic v) => (v is List ? v : const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> get accounts => _list(data?['accounts']);
  List<Map<String, dynamic>> get validIds => _list(data?['valid_ids']);
  String get _snapshot =>
      jsonEncode({...form, 'compliance': (compliance.toList()..sort())});
  bool get dirty => data != null && _snapshot != saved;

  Future<void> _load() async {
    setState(() => error = '');
    try {
      final r = Map<String, dynamic>.from(await api.call('show'));
      final c = Map<String, dynamic>.from(r['client'] ?? {});
      setState(() {
        data = r;
        form = {
          for (final k in _clientFields)
            k: _dateFields.contains(k) ? _day(c[k]) : _s(c[k]),
        };
        compliance = _s(
          c['compliance_ids'],
        ).split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toSet();
        saved = _snapshot;
      });
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<bool> _saveClient() async {
    if ((form['last_name'] ?? '').trim().isEmpty) {
      _snack(_t('Last name is required.', '请填写姓氏。'), false);
      return false;
    }
    setState(() => saving = true);
    try {
      final body = <String, dynamic>{
        for (final k in _clientFields)
          k: (form[k] ?? '').trim().isEmpty
              ? null
              : (k.endsWith('_id') ? int.tryParse(form[k]!) : form[k]!.trim()),
        'compliance_ids': compliance
            .map(int.tryParse)
            .whereType<int>()
            .toList(),
      };
      await api.call('client', body: body);
      setState(() => saved = _snapshot);
      _snack(_t('Settings saved', '设置已保存'), true);
      return true;
    } catch (e) {
      _snack('$e', false);
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String m, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? _ink : _red,
      content: Text(m),
    ),
  );

  /* ---------- documents (unchanged logic) ---------- */
  Future<void> _fetchDocuments() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/documents'),
      );
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (d['result'] == 'Success' && mounted)
          setState(
            () => documents = List<Map<String, dynamic>>.from(d['invoices']),
          );
      }
    } catch (_) {}
  }

  /* =========================================================
     UI
     ========================================================= */
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final loc = AppLocalizations.of(context);
    final sections = <List<dynamic>>[
      ['profile', _t('Profile', '个人资料'), Icons.person_outline_rounded, null],
      ['contact', _t('Contact', '联系方式'), Icons.call_outlined, null],
      ['address', _t('Address', '地址'), Icons.location_on_outlined, null],
      [
        'ownership',
        _t('Business Ownership', '企业所有权'),
        Icons.apartment_rounded,
        null,
      ],
      [
        'classification',
        _t('Classification & Compliance', '分类与合规'),
        Icons.verified_outlined,
        null,
      ],
      [
        'engagement',
        _t('Engagement', '合作'),
        Icons.event_available_outlined,
        null,
      ],
      ['ids', _t('Valid IDs', '有效证件'), Icons.badge_outlined, validIds.length],
      [
        'accounts',
        _t('Business Accounts', '企业账户'),
        Icons.storefront_outlined,
        accounts.length,
      ],
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text(
          loc.profile,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawer: AppDrawer(selectedIndex: 1),
      body: data == null && error.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : RefreshIndicator(
              color: _indigo,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                children: [
                  _header(auth),
                  const SizedBox(height: 14),
                  if (error.isNotEmpty) _errorBox(),
                  if (data != null) ...[
                    _groupTitle(_t('SETTINGS', '设置')),
                    _group([
                      for (final s in sections)
                        _navTile(
                          s[0] as String,
                          s[1] as String,
                          s[2] as IconData,
                          s[3] as int?,
                        ),
                    ]),
                    const SizedBox(height: 14),
                  ],
                  _groupTitle(_t('APP', '应用')),
                  _group([
                    _navTile(
                      'language',
                      loc.languageSettings,
                      Icons.language_rounded,
                      null,
                      trailing: Provider.of<LocaleProvider>(
                        context,
                      ).languageName,
                    ),
                    _navTile(
                      'documents',
                      loc.documents,
                      Icons.folder_open_rounded,
                      documents.length,
                    ),
                  ]),
                ],
              ),
            ),
    );
  }

  Widget _header(AuthProvider auth) {
    final name = auth.fullName.isNotEmpty
        ? auth.fullName
        : AppLocalizations.of(context).fullname;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(.22),
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${auth.username}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.8),
                    fontSize: 12.5,
                  ),
                ),
                if (auth.tradeName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      [
                        auth.tradeName,
                        if (auth.branchCode.isNotEmpty) auth.branchCode,
                        if (auth.tin.isNotEmpty) 'TIN ${auth.tin}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: _red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            error,
            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
          ),
        ),
        TextButton(onPressed: _load, child: Text(_t('Retry', '重试'))),
      ],
    ),
  );

  Widget _groupTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Text(
      t,
      style: const TextStyle(
        color: _faint,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _group(List<Widget> tiles) => Container(
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 58, color: _line),
          tiles[i],
        ],
      ],
    ),
  );

  Widget _navTile(
    String key,
    String label,
    IconData icon,
    int? badge, {
    String? trailing,
  }) => ListTile(
    onTap: () => _open(key, label),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _indigo, size: 19),
    ),
    title: Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Text(trailing, style: const TextStyle(color: _muted, fontSize: 12.5)),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: _faint),
      ],
    ),
  );

  void _open(String key, String title) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                _SectionPage(state: this, section: key, title: title),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  /* ---------- pickers ---------- */
  List<Map<String, String>> opts(dynamic list) => _list(
    list,
  ).map((o) => {'value': _s(o['id']), 'label': _s(o['label'])}).toList();

  Future<String?> pick(
    String title,
    List<Map<String, String>> options,
    String current,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) =>
          _PickerSheet(title: title, options: options, current: current),
    );
  }
}

/* =========================================================
   One section (same fields as the web)
   ========================================================= */
class _SectionPage extends StatefulWidget {
  const _SectionPage({
    required this.state,
    required this.section,
    required this.title,
  });
  final _ProfileScreenState state;
  final String section;
  final String title;

  @override
  State<_SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<_SectionPage> {
  _ProfileScreenState get p => widget.state;
  Map<String, String> get f => p.form;
  String _t(String en, String zh) => p._t(en, zh);
  final Map<String, List<Map<String, String>>> _cities = {}, _brgys = {};

  void _setF(String k, String v) => setState(() => p.setState(() => f[k] = v));

  bool get _clientSection => const [
    'profile',
    'contact',
    'address',
    'ownership',
    'classification',
    'engagement',
  ].contains(widget.section);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (widget.section == 'ids')
            IconButton(
              icon: const Icon(Icons.add_rounded, color: _indigo),
              onPressed: () => _idForm(null),
            ),
          if (widget.section == 'accounts')
            IconButton(
              icon: const Icon(Icons.add_rounded, color: _indigo),
              onPressed: () => _accountForm(null),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
        children: [_body()],
      ),
      bottomNavigationBar: _clientSection
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: p.saving || !p.dirty
                        ? null
                        : () async {
                            final ok = await p._saveClient();
                            if (ok && mounted) setState(() {});
                          },
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
                      p.saving
                          ? _t('Saving…', '保存中…')
                          : p.dirty
                          ? _t('Save changes', '保存更改')
                          : _t('No changes', '无更改'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body() {
    final L = p.L;
    switch (widget.section) {
      case 'profile':
        return _panel([
          _text('last_name', _t('Last name', '姓'), required: true),
          _text('first_name', _t('First name', '名')),
          _text('middle_name', _t('Middle name', '中间名')),
          _text('suffix', _t('Suffix', '后缀'), hint: 'Jr., Sr., III…'),
          _label(_t('Gender', '性别')),
          _seg('gender', const [
            ['MALE', 'Male', '男'],
            ['FEMALE', 'Female', '女'],
          ]),
          const SizedBox(height: 12),
          _date('birthdate', _t('Date of birth', '出生日期')),
          _select(
            'civ_stat_id',
            _t('Civil status', '婚姻状况'),
            p.opts(L['civil']),
          ),
          const Text(
            '* Required',
            style: TextStyle(color: _faint, fontSize: 11.5),
          ),
        ]);
      case 'contact':
        return _panel([
          _text(
            'phone_num',
            _t('Cellphone number', '手机号码'),
            type: TextInputType.phone,
          ),
          _text(
            'tell_num',
            _t('Telephone number', '电话号码'),
            type: TextInputType.phone,
          ),
          _text(
            'email_address',
            _t('Email address', '电子邮箱'),
            type: TextInputType.emailAddress,
          ),
        ]);
      case 'address':
        return _panel([
          ..._addressPickers(f, (k, v) => _setF(k, v)),
          _text('street', _t('Street name / district', '街道 / 区'), lines: 3),
        ]);
      case 'ownership':
        final bot = p._list(L['bot']);
        final cur = bot.firstWhere(
          (b) => _s(b['id']) == f['business_ownership_type_id'],
          orElse: () => {},
        );
        return _panel([
          _select(
            'business_ownership_type_id',
            _t('Business ownership type', '企业所有权类型'),
            p.opts(bot),
            onPicked: () => _setF('business_ownership_type_detail_id', ''),
          ),
          if (p._list(cur['details']).isNotEmpty)
            _select(
              'business_ownership_type_detail_id',
              _t('Type detail', '类型明细'),
              p.opts(cur['details']),
            ),
        ]);
      case 'classification':
        final comp = p.opts(L['compliance']);
        return _panel([
          _select(
            'classification_id',
            _t('Classification', '分类'),
            p.opts(L['classification']),
          ),
          _select(
            'industries_id',
            _t('Industry', '行业'),
            p.opts(L['industries']),
          ),
          _label(_t('Compliance', '合规')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in comp)
                FilterChip(
                  label: Text(c['label']!),
                  selected: p.compliance.contains(c['value']),
                  onSelected: (on) => setState(
                    () => p.setState(
                      () => on
                          ? p.compliance.add(c['value']!)
                          : p.compliance.remove(c['value']),
                    ),
                  ),
                  selectedColor: const Color(0xFFEEF2FF),
                  checkmarkColor: _indigo,
                  backgroundColor: _card,
                  side: BorderSide(
                    color: p.compliance.contains(c['value'])
                        ? const Color(0xFFC7D2FE)
                        : _line,
                  ),
                  labelStyle: TextStyle(
                    color: p.compliance.contains(c['value']) ? _indigo : _muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ]);
      case 'engagement':
        return _panel([
          _date('date_of_engagement', _t('Date of engagement', '合作日期')),
          _date('date_of_disengagement', _t('Date of disengagement', '终止日期')),
          _date('date_started', _t('Date started', '开始日期')),
          _date('date_registered', _t('Date registered', '注册日期')),
        ]);
      case 'ids':
        final ids = p.validIds;
        if (ids.isEmpty)
          return _empty(
            _t('No valid IDs yet. Tap + to add one.', '暂无证件，点击 + 添加。'),
          );
        return Column(
          children: [
            for (final v in ids)
              _rowCard(
                icon: Icons.badge_outlined,
                title: _s(v['institution']),
                sub: _s(v['id_num']),
                onTap: () => _idForm(v),
                onDelete: () => _deleteId(v),
              ),
          ],
        );
      case 'accounts':
        final acc = p.accounts;
        if (acc.isEmpty)
          return _empty(
            _t(
              'No business accounts yet. Tap + to add one.',
              '暂无企业账户，点击 + 添加。',
            ),
          );
        return Column(
          children: [
            for (final a in acc)
              _rowCard(
                icon: Icons.storefront_outlined,
                title: _s(a['trade_name']),
                sub: [
                  _s(a['branch_code']),
                  _s(a['branch_type']),
                  _s(a['nature_label']),
                  _s(a['status_label']),
                ].where((x) => x.isNotEmpty).join(' · '),
                pill: (int.tryParse(_s(a['is_active'])) ?? 1) == 1
                    ? null
                    : _t('Inactive', '停用'),
                onTap: () => _accountForm(a),
                onDelete: () => _deleteAccount(a),
              ),
          ],
        );
      case 'language':
        final lp = Provider.of<LocaleProvider>(context);
        return _panel([
          for (final o in const [
            ['en', 'English', 'EN'],
            ['zh', '中文', 'CN'],
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => lp.setLanguageCode(o[0]),
              leading: Icon(
                (o[0] == 'en' ? lp.isEnglish : lp.isChinese)
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: (o[0] == 'en' ? lp.isEnglish : lp.isChinese)
                    ? _indigo
                    : _faint,
              ),
              title: Text(
                o[1],
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(o[2], style: const TextStyle(color: _muted)),
            ),
        ]);
      case 'documents':
        if (p.documents.isEmpty) return _empty(_t('No documents.', '暂无文件。'));
        final auth = Provider.of<AuthProvider>(context, listen: false);
        return Column(
          children: [
            for (final d in p.documents)
              _rowCard(
                icon: Icons.description_outlined,
                title: _s(d['DocumentName']),
                sub: _t('Tap to view or change', '点击查看或更换'),
                onTap: () => _showDocumentImage(
                  _s(d['DocumentName']),
                  'https://igb-fems.com/LIVE/images/Documents/${auth.comId}-${d['ID']}.webp?v=${DateTime.now().millisecondsSinceEpoch}',
                  _s(d['ID']),
                ),
              ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  /* ---------- form widgets ---------- */
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

  Widget _label(String t, {bool required = false}) => Padding(
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

  InputDecoration _dec({String? hint, Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _faint),
    suffixIcon: suffix,
    isDense: true,
    filled: true,
    fillColor: _card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDBE2EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _indigo, width: 1.5),
    ),
  );

  Widget _text(
    String k,
    String label, {
    bool required = false,
    String? hint,
    TextInputType? type,
    int lines = 1,
    Map<String, String>? into,
    void Function(String, String)? onSet,
  }) {
    final src = into ?? f;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label, required: required),
          TextFormField(
            key: ValueKey('$k-${into == null ? 'c' : 'x'}'),
            initialValue: src[k] ?? '',
            keyboardType: type,
            maxLines: lines,
            style: const TextStyle(color: _ink, fontSize: 14.5),
            decoration: _dec(hint: hint),
            onChanged: (v) => onSet != null ? onSet(k, v) : _setF(k, v),
          ),
        ],
      ),
    );
  }

  Widget _boxButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool placeholder = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE2EA)),
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

  Widget _select(
    String k,
    String label,
    List<Map<String, String>> options, {
    Map<String, String>? into,
    void Function(String, String)? onSet,
    VoidCallback? onPicked,
  }) {
    final src = into ?? f;
    final cur = options.firstWhere(
      (o) => o['value'] == src[k],
      orElse: () => {'label': ''},
    )['label']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          _boxButton(
            cur.isEmpty ? '—' : cur,
            Icons.expand_more_rounded,
            () async {
              final v = await p.pick(label, [
                {'value': '', 'label': '—'},
                ...options,
              ], src[k] ?? '');
              if (v == null) return;
              onSet != null ? onSet(k, v) : _setF(k, v);
              onPicked?.call();
              setState(() {});
            },
            placeholder: cur.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _date(String k, String label) {
    final v = f[k] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          Row(
            children: [
              Expanded(
                child: _boxButton(
                  v.isEmpty ? '—' : v,
                  Icons.event_rounded,
                  () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(v) ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: _indigo,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null)
                      _setF(
                        k,
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                      );
                  },
                  placeholder: v.isEmpty,
                ),
              ),
              if (v.isNotEmpty)
                IconButton(
                  onPressed: () => _setF(k, ''),
                  icon: const Icon(Icons.close_rounded, color: _faint),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seg(String k, List<List<String>> options) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => _setF(k, o[0]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: f[k] == o[0] ? _card : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: f[k] == o[0]
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
                  p._zh ? o[2] : o[1],
                  style: TextStyle(
                    color: f[k] == o[0] ? _indigo : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// Province → City / Municipality → Barangay (same as the web AddressPicker)
  List<Widget> _addressPickers(
    Map<String, String> src,
    void Function(String, String) put,
  ) {
    final pid = src['province_id'] ?? '', cid = src['city_id'] ?? '';
    if (pid.isNotEmpty && !_cities.containsKey(pid))
      _loadList('cities', {'province_id': pid}, _cities, pid);
    if (cid.isNotEmpty && !_brgys.containsKey(cid))
      _loadList('barangays', {'city_id': cid}, _brgys, cid);
    return [
      _select(
        'province_id',
        _t('Province', '省'),
        p.opts(p.L['provinces']),
        into: src,
        onSet: (k, v) {
          put(k, v);
          put('city_id', '');
          put('brgy_id', '');
        },
      ),
      _select(
        'city_id',
        _t('City / Municipality', '市 / 镇'),
        _cities[pid] ?? const [],
        into: src,
        onSet: (k, v) {
          put(k, v);
          put('brgy_id', '');
        },
      ),
      _select(
        'brgy_id',
        _t('Barangay', '村'),
        _brgys[cid] ?? const [],
        into: src,
        onSet: put,
      ),
    ];
  }

  Future<void> _loadList(
    String action,
    Map<String, String> q,
    Map<String, List<Map<String, String>>> into,
    String key,
  ) async {
    into[key] = const [];
    try {
      final r = await p.api.call(action, query: q);
      into[key] = p.opts(r);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget _empty(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        const Icon(Icons.inbox_rounded, size: 48, color: _faint),
        const SizedBox(height: 10),
        Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );

  Widget _rowCard({
    required IconData icon,
    required String title,
    required String sub,
    String? pill,
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: _indigo, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        sub,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pill != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pill,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: _red,
                size: 20,
              ),
            ),
        ],
      ),
    ),
  );

  /* ---------- valid IDs ---------- */
  Future<void> _idForm(Map<String, dynamic>? v) async {
    final m = <String, String>{
      'institution': _s(v?['institution']).isEmpty
          ? 'BIR'
          : _s(v?['institution']),
      'id_num': _s(v?['id_num']),
    };
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final tinCtrl = TextEditingController(text: m['id_num']);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  v == null
                      ? _t('Add valid ID', '添加证件')
                      : _t('Edit valid ID', '编辑证件'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _label(_t('Institution', '机构')),
                _boxButton(
                  m['institution']!,
                  Icons.expand_more_rounded,
                  () async {
                    final x = await p.pick(_t('Institution', '机构'), [
                      for (final i in _institutions) {'value': i, 'label': i},
                    ], m['institution']!);
                    if (x != null && x.isNotEmpty)
                      ss(() => m['institution'] = x);
                  },
                ),
                const SizedBox(height: 12),
                _label(
                  m['institution'] == 'BIR'
                      ? 'TIN (000-000-000)'
                      : _t('ID number', '证件号码'),
                  required: true,
                ),
                TextField(
                  controller: tinCtrl
                    ..selection = TextSelection.collapsed(
                      offset: tinCtrl.text.length,
                    ),
                  keyboardType: m['institution'] == 'BIR'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: _dec(
                    hint: m['institution'] == 'BIR' ? '000-000-000' : null,
                  ),
                  style: const TextStyle(color: _ink),
                  onChanged: (x) => ss(
                    () => m['id_num'] = m['institution'] == 'BIR'
                        ? _fmtTin(x)
                        : x,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _t('Save', '保存'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    if (m['institution'] == 'BIR' &&
        !RegExp(r'^\d{3}-\d{3}-\d{3}$').hasMatch(m['id_num']!.trim())) {
      p._snack(
        _t(
          'Enter the TIN as 000-000-000 (9 digits).',
          '请输入 TIN 格式 000-000-000（9 位数字）。',
        ),
        false,
      );
      return;
    }
    try {
      final r = await p.api.call(
        v == null ? 'id_store' : 'id_update',
        body: m,
        query: v == null ? null : {'id': _s(v['id'])},
      );
      p.setState(() => p.data!['valid_ids'] = r['valid_ids']);
      setState(() {});
      p._snack(_t('Saved', '已保存'), true);
    } catch (e) {
      p._snack('$e', false);
    }
  }

  Future<void> _deleteId(Map<String, dynamic> v) async {
    final ok = await _confirm(
      _t('Delete this ID?', '删除此证件？'),
      '${v['institution']} · ${v['id_num']}',
    );
    if (ok != true) return;
    try {
      final r = await p.api.call(
        'id_delete',
        body: {},
        query: {'id': _s(v['id'])},
      );
      p.setState(() => p.data!['valid_ids'] = r['valid_ids']);
      setState(() {});
    } catch (e) {
      p._snack('$e', false);
    }
  }

  /* ---------- business accounts ---------- */
  Future<void> _accountForm(Map<String, dynamic>? a) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AccountPage(section: this, account: a),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _deleteAccount(Map<String, dynamic> a) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        surfaceTintColor: _card,
        title: Text(_t('Delete ${a['trade_name']}?', '删除 ${a['trade_name']}？')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Type the branch code ${a['branch_code']} to confirm.',
                '输入分店代码 ${a['branch_code']} 以确认。',
              ),
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: code,
              decoration: _dec(hint: _s(a['branch_code'])),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', '取消')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(_t('Delete', '删除')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await p.api.call(
        'account_delete',
        body: {'confirm': code.text.trim()},
        query: {'id': _s(a['id'])},
      );
      p.setState(() => p.data!['accounts'] = r['accounts']);
      setState(() {});
    } catch (e) {
      p._snack('$e', false);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      surfaceTintColor: _card,
      title: Text(title),
      content: Text(body, style: const TextStyle(color: _muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(_t('Cancel', '取消')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text(_t('Delete', '删除')),
        ),
      ],
    ),
  );

  /* ---------- documents (same as before) ---------- */
  void _showDocumentImage(String title, String imageUrl, String id) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          color: _card,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _ink),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, prog) => prog == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(color: _indigo),
                          ),
                    errorBuilder: (c, e, s) => const Center(
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadImage(ctx, id, title, imageUrl),
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(
                        AppLocalizations.of(context).changeUploadImage,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadImage(
    BuildContext ctx,
    String id,
    String title,
    String imageUrl,
  ) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    p._snack('Uploading image...', true);
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConstants.baseUrl}/upload_document'),
            )
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                await image.readAsBytes(),
                filename: '${auth.comId}-$id.webp',
                contentType: MediaType('image', 'webp'),
              ),
            )
            ..fields['comId'] = auth.comId
            ..fields['id'] = id;
      final res = await req.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200 && json.decode(body)['success'] == true) {
        p._snack('Image uploaded successfully', true);
        if (ctx.mounted) Navigator.of(ctx).pop();
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _showDocumentImage(title, imageUrl, id),
        );
      } else {
        p._snack('Upload failed: $body', false);
      }
    } catch (e) {
      p._snack('Error: $e', false);
    }
  }
}

/* =========================================================
   Business account form (same fields as the web)
   ========================================================= */
class _AccountPage extends StatefulWidget {
  const _AccountPage({required this.section, this.account});
  final _SectionPageState section;
  final Map<String, dynamic>? account;

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  _SectionPageState get s => widget.section;
  _ProfileScreenState get p => s.p;
  late final Map<String, String> a;
  bool saving = false;

  static const _fields = [
    'trade_name',
    'nob_id',
    'branch_type',
    'branch_code',
    'tax_registration',
    'rdo',
    'status_id',
    'street',
    'province_id',
    'city_id',
    'brgy_id',
    'phone_num',
    'tell_num',
    'email_address',
  ];

  @override
  void initState() {
    super.initState();
    final x = widget.account ?? {};
    a = {for (final k in _fields) k: _s(x[k])};
    if (widget.account == null) {
      a['branch_type'] = 'BRANCH';
      a['branch_code'] = '0000';
    }
    a['is_active'] = widget.account == null
        ? '1'
        : ((int.tryParse(_s(x['is_active'])) ?? 1) == 1 ? '1' : '0');
  }

  void put(String k, String v) => setState(() => a[k] = v);

  Future<void> _save() async {
    if (a['trade_name']!.trim().isEmpty || a['branch_code']!.trim().isEmpty) {
      p._snack(
        p._t('Trade name and branch code are required.', '请填写商号和分店代码。'),
        false,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final body = <String, dynamic>{
        for (final k in _fields)
          k: a[k]!.trim().isEmpty
              ? null
              : (k.endsWith('_id') ? int.tryParse(a[k]!) : a[k]!.trim()),
        'branch_type': a['branch_type']!.isEmpty ? 'BRANCH' : a['branch_type'],
        'is_active': a['is_active'] == '1',
      };
      final r = await p.api.call(
        widget.account == null ? 'account_store' : 'account_update',
        body: body,
        query: widget.account == null
            ? null
            : {'id': _s(widget.account!['id'])},
      );
      p.setState(() => p.data!['accounts'] = r['accounts']);
      if (mounted) Navigator.pop(context, true);
      p._snack(p._t('Business account saved', '企业账户已保存'), true);
    } catch (e) {
      p._snack('$e', false);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = p.L;
    final branchTypes = p._list(L['branch_types']).isNotEmpty
        ? p
              ._list(L['branch_types'])
              .map(
                (b) => {
                  'value': _s(b['label']).toUpperCase(),
                  'label': _s(b['label']),
                },
              )
              .toList()
        : [
            {'value': 'MAIN', 'label': 'MAIN'},
            {'value': 'BRANCH', 'label': 'BRANCH'},
          ];
    final taxReg = p
        ._list(L['tax_reg'])
        .map((t) => {'value': _s(t['label']), 'label': _s(t['label'])})
        .toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Text(
          widget.account == null
              ? p._t('New business account', '新建企业账户')
              : _s(widget.account!['trade_name']),
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
        children: [
          s._panel([
            s._text(
              'trade_name',
              p._t('Trade name', '商号'),
              required: true,
              into: a,
              onSet: put,
            ),
            s._select(
              'nob_id',
              p._t('Nature of business', '经营性质'),
              p.opts(L['nature']),
              into: a,
              onSet: put,
            ),
            s._select(
              'branch_type',
              p._t('Branch type', '分店类型'),
              branchTypes,
              into: a,
              onSet: put,
            ),
            s._text(
              'branch_code',
              p._t('Branch code', '分店代码'),
              required: true,
              into: a,
              onSet: put,
            ),
            s._select(
              'tax_registration',
              p._t('Tax registration', '税务登记'),
              taxReg,
              into: a,
              onSet: put,
            ),
            if (p.data?['has_rdo'] == true)
              s._text('rdo', 'RDO', into: a, onSet: put),
            s._select(
              'status_id',
              p._t('Status', '状态'),
              p.opts(L['status']),
              into: a,
              onSet: put,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: a['is_active'] == '1',
              onChanged: (v) => put('is_active', v ? '1' : '0'),
              activeColor: _green,
              title: Text(
                p._t('Active', '启用'),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          s._panel([
            ...s._addressPickers(a, put),
            s._text(
              'street',
              p._t('Street name / district', '街道 / 区'),
              lines: 2,
              into: a,
              onSet: put,
            ),
            s._text(
              'phone_num',
              p._t('Cellphone number', '手机号码'),
              type: TextInputType.phone,
              into: a,
              onSet: put,
            ),
            s._text(
              'tell_num',
              p._t('Telephone number', '电话号码'),
              type: TextInputType.phone,
              into: a,
              onSet: put,
            ),
            s._text(
              'email_address',
              p._t('Email address', '电子邮箱'),
              type: TextInputType.emailAddress,
              into: a,
              onSet: put,
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                saving
                    ? p._t('Saving…', '保存中…')
                    : p._t('Save business account', '保存企业账户'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================================================
   searchable picker (like the web SearchSelect)
   ========================================================= */
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.current,
  });
  final String title;
  final List<Map<String, String>> options;
  final String current;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.options
        .where(
          (o) =>
              q.isEmpty || o['label']!.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: widget.options.length > 12,
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search_rounded, color: _faint),
                    isDense: true,
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
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
                          final on = o['value'] == widget.current;
                          return ListTile(
                            dense: true,
                            onTap: () => Navigator.pop(context, o['value']),
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
  }
}
