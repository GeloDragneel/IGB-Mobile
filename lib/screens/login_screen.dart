import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'calendar.dart';
import 'dashboard.dart';

/// Same look as the web login (Login.jsx): white card, indigo brand,
/// Google / Facebook, free-trial note, divider, floating-label fields, shake on error.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/* ---------- web palette ---------- */
const _indigo = Color(0xFF4F46E5);
const _indigoDark = Color(0xFF4338CA);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _line = Color(0xFFDBE2EA);
const _lineSoft = Color(0xFFE2E8F0);
const _page = Color(0xFFF4F6FB);
const _red = Color(0xFFDC2626);

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _localAuth = LocalAuthentication();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();

  late final AnimationController _enter;
  late final AnimationController _shake;
  late final AnimationController _pulse;

  bool _busy = false;
  bool _isAuthenticating = false;
  bool _showPw = false;
  String _mode =
      'choose'; // choose = 4 buttons · password = username/password · bio = fingerprint
  String _error = '';

  List<Map<String, dynamic>> _registeredAccounts = [];

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _loadBiometricData();
  }

  @override
  void dispose() {
    _enter.dispose();
    _shake.dispose();
    _pulse.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  /* ---------- helpers ---------- */
  bool get _zh => Provider.of<LocaleProvider>(context, listen: false).isChinese;
  String _t(String en, String zh) => _zh ? zh : en;

  void _fail(String msg) {
    setState(() => _error = msg);
    _shake.forward(from: 0);
  }

  void _go(AuthProvider auth) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.userCount == 'User2'
            ? const CalendarScreen()
            : const Dashboard(),
      ),
    );
  }

  /* ---------- username / password ---------- */
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final loc = AppLocalizations.of(context);
    setState(() => _error = '');
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _fail(_t('Enter your username and password.', '请输入用户名和密码。'));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _busy = true);
    final String result = await auth.login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result == 'Success') {
      _go(auth);
      return;
    }
    _fail(
      result == 'NotCorrect'
          ? loc.invalidUserOrPass
          : result == 'ResetPassword'
          ? loc.passwordResetRequired
          : result == 'Duplicate'
          ? loc.duplicateUserDetected
          : result == 'Attempt'
          ? loc.tooManyAttempts
          : result == 'InvalidScanAccess'
          ? loc.invalidScanAccess
          : loc.loginError,
    );
  }

  /* ---------- fingerprint (unchanged logic) ---------- */
  Future<void> _loadBiometricData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKeys = prefs.getString('biometric_caids') ?? '';
      if (storedKeys.isEmpty) {
        if (mounted) setState(() => _registeredAccounts = []);
        return;
      }
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/biometric_validation?keys=$storedKeys',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          final List accounts = data['data'];
          final serverKeys = accounts
              .map((item) => '${item['CAID']}_${item['UserID']}')
              .join(',');
          await prefs.setString('biometric_caids', serverKeys);
          if (!mounted) return;
          setState(() {
            _registeredAccounts = accounts
                .map((item) {
                  final caid = item['CAID'].toString();
                  final userId = item['UserID'].toString();
                  return {'key': '${caid}_$userId', 'caid': caid, 'data': item};
                })
                .toList()
                .cast<Map<String, dynamic>>();
          });
        } else if (mounted) {
          setState(() => _registeredAccounts = []);
        }
      }
    } catch (e) {
      debugPrint('Error loading biometric data: $e');
      if (mounted) setState(() => _registeredAccounts = []);
    }
  }

  Future<void> _loginWithBiometric() async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _isAuthenticating = true;
      _error = '';
    });
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login with fingerprint',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _isAuthenticating = false);
        return;
      }
      await _loadBiometricData();
      if (!mounted) return;
      if (_registeredAccounts.isEmpty) {
        setState(() => _isAuthenticating = false);
        _fail(loc.noBiometricRegistered);
        return;
      }
      setState(() => _isAuthenticating = false);

      final selected = _registeredAccounts.length == 1
          ? _registeredAccounts.first
          : await _showAccountPicker();
      if (selected == null || !mounted) return;

      setState(() => _isAuthenticating = true);
      final server = selected['data'] as Map<String, dynamic>;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // the server logs in the registered account (CAID + UserID) – no password is sent to the phone
      final result = await auth.loginWithBiometricKey(
        caid: selected['caid'].toString(),
        userId: server['UserID'].toString(),
        username: server['Username']?.toString() ?? '',
      );
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      if (result == 'Success') {
        _go(auth);
      } else {
        _fail('${loc.loginFailed}: $result');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAuthenticating = false);
      _fail('${loc.authenticationError}: $e');
    }
  }

  Future<Map<String, dynamic>?> _showAccountPicker() {
    final loc = AppLocalizations.of(context);
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _lineSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loc.selectAccount,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc.chooseAnAccountToContinueWith,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _registeredAccounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = _registeredAccounts[i];
                    final d = a['data'] as Map<String, dynamic>;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, a),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _lineSoft),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5FF)],
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _indigo,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['TradeName']?.toString() ??
                                        'CAID ${a['caid']}',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    d['Username']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _faint,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(
                    loc.cancel,
                    style: const TextStyle(color: _muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------- Google / Facebook ---------- */
  void _social(String name) {
    _fail(
      _t(
        '$name sign-in on the app is coming soon. Use your username for now.',
        '应用内 $name 登录即将推出，请先使用用户名登录。',
      ),
    );
  }

  /* ---------- language ---------- */
  void _showLanguageDialog(LocaleProvider lp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final o in const [
              ['en', 'English', 'EN'],
              ['zh', '中文', 'CN'],
            ])
              ListTile(
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
                onTap: () {
                  lp.setLanguageCode(o[0]);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /* =========================================================
     UI
     ========================================================= */
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final lp = Provider.of<LocaleProvider>(context);
    final locked = _busy || _isAuthenticating;

    return PopScope(
      canPop: _mode == 'choose',
      onPopInvoked: (didPop) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _page,
        body: Stack(
          children: [
            // soft blobs like .lg-blob-a / .lg-blob-b
            const Positioned(
              top: -140,
              left: -120,
              child: _Blob(size: 360, color: Color(0xFF818CF8)),
            ),
            const Positioned(
              bottom: -160,
              right: -140,
              child: _Blob(size: 400, color: Color(0xFF38BDF8)),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    right: 16,
                    child: _LangChip(
                      label: lp.isEnglish ? 'EN' : '中文',
                      onTap: () => _showLanguageDialog(lp),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _enter,
                          curve: Curves.easeOut,
                        ),
                        child: SlideTransition(
                          position:
                              Tween(
                                begin: const Offset(0, .04),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _enter,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _shake,
                                  builder: (_, child) => Transform.translate(
                                    offset: Offset(
                                      math.sin(_shake.value * math.pi * 6) *
                                          10 *
                                          (1 - _shake.value),
                                      0,
                                    ),
                                    child: child,
                                  ),
                                  child: _card(loc, locked),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '© ${DateTime.now().year} IGB. All rights reserved.',
                                  style: const TextStyle(
                                    color: _faint,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _card(AppLocalizations loc, bool locked) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lineSoft),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(.08),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _ink.withOpacity(.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // brand (.lg-mobile-brand)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), _indigoDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _indigo.withOpacity(.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  'IGB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'IGB Accounting',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // head (.lg-head)
          Text(
            loc.welcomeBack,
            style: const TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('Sign in to your account to continue.', '登录您的账户以继续。'),
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // error (.lg-error)
          if (_error.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _mode == 'password'
                  ? _passwordForm(loc, locked)
                  : _mode == 'bio'
                  ? _bioPanel(loc)
                  : _options(loc, locked),
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_busy || _isAuthenticating) return;
    setState(() {
      _mode = 'choose';
      _error = '';
    });
  }

  void _startBio() {
    setState(() {
      _mode = 'bio';
      _error = '';
    });
    _loginWithBiometric();
  }

  Widget _backLink() => TextButton.icon(
    onPressed: (_busy || _isAuthenticating) ? null : _back,
    style: TextButton.styleFrom(foregroundColor: _muted),
    icon: const Icon(Icons.arrow_back_rounded, size: 18),
    label: Text(
      _t('Other sign-in options', '其他登录方式'),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  /// the 4 sign-in buttons
  Widget _options(AppLocalizations loc, bool locked) {
    return Column(
      key: const ValueKey('choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: _t('Continue with Google', '使用 Google 继续'),
          icon: const _GoogleG(),
          onTap: locked ? null : () => _social('Google'),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: _t('Continue with Facebook', '使用 Facebook 继续'),
          icon: const Icon(
            Icons.facebook_rounded,
            color: Color(0xFF1877F2),
            size: 20,
          ),
          onTap: locked ? null : () => _social('Facebook'),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: _t('Continue with Password', '使用密码继续'),
          icon: const Icon(
            Icons.lock_outline_rounded,
            color: _indigo,
            size: 20,
          ),
          onTap: locked
              ? null
              : () => setState(() {
                  _mode = 'password';
                  _error = '';
                }),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: _t('Continue with Biometric', '使用生物识别继续'),
          icon: const Icon(Icons.fingerprint_rounded, color: _indigo, size: 22),
          onTap: locked ? null : _startBio,
        ),
        const SizedBox(height: 16),

        // free trial (.lg-trial)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC7D2FE)),
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFEEF2FF)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: _indigo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        'New client? Try it free for 15 days',
                        '新客户？免费试用 15 天',
                      ),
                      style: const TextStyle(
                        color: _indigoDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t(
                        'Use Google or Facebook above · no payment needed',
                        '使用上方 Google 或 Facebook · 无需付款',
                      ),
                      style: const TextStyle(color: _muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Continue with Password → username + password
  Widget _passwordForm(AppLocalizations loc, bool locked) {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controller: _userCtrl,
          label: loc.username,
          icon: Icons.person_outline_rounded,
          action: TextInputAction.next,
          onSubmit: (_) => _passFocus.requestFocus(),
          autofill: const [AutofillHints.username],
        ),
        const SizedBox(height: 12),
        _field(
          controller: _passCtrl,
          focus: _passFocus,
          label: loc.password,
          icon: Icons.lock_outline_rounded,
          obscure: !_showPw,
          action: TextInputAction.done,
          onSubmit: (_) => locked ? null : _submit(),
          autofill: const [AutofillHints.password],
          suffix: TextButton(
            onPressed: () => setState(() => _showPw = !_showPw),
            style: TextButton.styleFrom(
              foregroundColor: _indigo,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              _showPw ? _t('Hide', '隐藏') : _t('Show', '显示'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {}, // same as web: no function yet
            style: TextButton.styleFrom(
              foregroundColor: _indigo,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              _t('Forgot password?', '忘记密码？'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _submitButton(loc, locked),
        const SizedBox(height: 10),
        _backLink(),
      ],
    );
  }

  /// Continue with Biometric → big fingerprint
  Widget _bioPanel(AppLocalizations loc) {
    final scanning = _isAuthenticating;
    return Column(
      key: const ValueKey('bio'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            onTap: scanning ? null : _loginWithBiometric,
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (scanning)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 110 + 60 * _pulse.value,
                        height: 110 + 60 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _indigo.withOpacity(.18 * (1 - _pulse.value)),
                        ),
                      ),
                    ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFC7D2FE),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _indigo.withOpacity(.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: _indigo,
                      size: 64,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          scanning
              ? _t('Touch the fingerprint sensor', '请触摸指纹传感器')
              : _t('Tap the fingerprint to try again', '点击指纹重试'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          loc.registerFingerprintViaEnable,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _faint, fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        _backLink(),
      ],
    );
  }

  Widget _submitButton(AppLocalizations loc, bool locked) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF6366F1), _indigo]),
          boxShadow: [
            BoxShadow(
              color: _indigo.withOpacity(.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: locked ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _t('Signing in…', '登录中…'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loc.signin,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focus,
    bool obscure = false,
    Widget? suffix,
    TextInputAction? action,
    ValueChanged<String>? onSubmit,
    Iterable<String>? autofill,
  }) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    final bad = _error.isNotEmpty && controller.text.isEmpty;
    return TextField(
      controller: controller,
      focusNode: focus,
      obscureText: obscure,
      textInputAction: action,
      onSubmitted: onSubmit,
      autofillHints: autofill,
      onChanged: (_) => _error.isNotEmpty ? setState(() {}) : null,
      style: const TextStyle(color: _ink, fontSize: 15),
      cursorColor: _indigo,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _faint, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: _indigo,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: _faint, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 14,
        ),
        enabledBorder: b(bad ? const Color(0xFFFCA5A5) : _line),
        focusedBorder: b(_indigo, 1.6),
        border: b(_line),
      ),
    );
  }
}

/* ---------- small pieces ---------- */
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(.28), color.withOpacity(0)],
        ),
      ),
    ),
  );
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _lineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: _indigo, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, this.onTap});
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
        ],
      ),
    ),
  );
}

/// Google "G" drawn in its four colors (no image asset needed).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CustomPaint(painter: _GPainter()),
  );
}

class _GPainter extends CustomPainter {
  const _GPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(
      s.width * .1,
      s.height * .1,
      s.width * .8,
      s.height * .8,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .18;
    void arc(Color c, double start, double sweep) =>
        canvas.drawArc(r, start, sweep, false, p..color = c);
    arc(const Color(0xFFEA4335), -2.6, 1.5); // red, top
    arc(const Color(0xFFFBBC05), 2.35, 1.0); // yellow, left-bottom
    arc(const Color(0xFF34A853), .75, 1.6); // green, bottom
    arc(const Color(0xFF4285F4), -.15, .9); // blue, right
    canvas.drawLine(
      Offset(s.width * .5, s.height * .5),
      Offset(s.width * .9, s.height * .5),
      p..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
