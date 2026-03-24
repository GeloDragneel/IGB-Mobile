import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import 'dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _localAuth = LocalAuthentication();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _username = '';
  String _password = '';
  bool _isAuthenticating = false;
  bool _obscurePassword = true;

  List<Map<String, dynamic>> _registeredAccounts = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadBiometricData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKeys = prefs.getString('biometric_caids') ?? '';

      if (storedKeys.isEmpty) {
        setState(() => _registeredAccounts = []);
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/biometric_validation.php'
          '?keys=$storedKeys',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'Success') {
          final List accounts = data['data'];

          // Sync back
          final serverKeys = accounts
              .map((item) => '${item['CAID']}_${item['UserID']}')
              .join(',');
          await prefs.setString('biometric_caids', serverKeys);

          setState(() {
            _registeredAccounts = accounts.map((item) {
              final caid = item['CAID'].toString();
              final userId = item['UserID'].toString();
              return {'key': '${caid}_$userId', 'caid': caid, 'data': item};
            }).toList();
          });
        } else {
          setState(() => _registeredAccounts = []);
        }
      }
    } catch (e) {
      debugPrint('Error loading biometric data: $e');
      setState(() => _registeredAccounts = []);
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _isAuthenticating = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login with fingerprint',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated || !mounted) {
        setState(() => _isAuthenticating = false);
        return;
      }

      await _loadBiometricData();

      if (!mounted) return;

      if (_registeredAccounts.isEmpty) {
        setState(() => _isAuthenticating = false);
        _showSnackBar('No biometric registered. Please register first.', false);
        return;
      }

      setState(() => _isAuthenticating = false);

      Map<String, dynamic>? selectedAccount;
      if (_registeredAccounts.length == 1) {
        selectedAccount = _registeredAccounts.first;
      } else {
        selectedAccount = await _showAccountPicker();
      }

      if (selectedAccount == null || !mounted) return;

      setState(() => _isAuthenticating = true);

      final serverData = selectedAccount['data'] as Map<String, dynamic>;
      final bioUsername = serverData['Username']?.toString() ?? '';
      final bioPassword = serverData['Password']?.toString() ?? '';

      if (bioUsername.isEmpty || bioPassword.isEmpty) {
        setState(() => _isAuthenticating = false);
        _showSnackBar(
          'Invalid credentials from server. Please re-register.',
          false,
        );
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String result = await authProvider.login(bioUsername, bioPassword);

      if (!mounted) return;
      setState(() => _isAuthenticating = false);

      if (result == 'Success') {
        _showSnackBar('Biometric login successful!', true);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Dashboard()),
        );
      } else {
        _showSnackBar('Login failed: $result', false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showSnackBar('Authentication error: $e', false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showAccountPicker() {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1923),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8f72ec).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      color: Color(0xFF8f72ec),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an account to continue with',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _registeredAccounts.asMap().entries.map((entry) {
                      final account = entry.value;
                      final serverData =
                          account['data'] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, account),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8f72ec),
                                          Color(0xFF6B4FD8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
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
                                          serverData['TradeName'] ??
                                              'CAID ${account['caid']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          serverData['Username'] ?? '',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withOpacity(0.3),
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
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

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success
            ? const Color(0xFF1A3A2A)
            : const Color(0xFF3A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030710),
      body: Stack(
        children: [
          Positioned(
            top: -160,
            left: -160,
            child: _ring(500, const Color(0xFF8f72ec), 0.06),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: _ring(600, const Color(0xFF4F8AEC), 0.05),
          ),
          Positioned(
            top: 80,
            right: -80,
            child: _ring(260, const Color(0xFF8f72ec), 0.08),
          ),
          Positioned.fill(
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 2,
                    height: 1200,
                    margin: const EdgeInsets.only(left: 60),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF8f72ec).withOpacity(0.12),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8f72ec),
                                    Color(0xFF5B3FD8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8f72ec,
                                    ).withOpacity(0.45),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'IGB FEMS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  'Accounting and Business Consultancy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 8,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Welcome\nback.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -1.5,
                            shadows: [
                              Shadow(
                                color: const Color(0xFF8f72ec).withOpacity(0.3),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue to your account',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1422),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF8f72ec).withOpacity(0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildField(
                                  label: 'USERNAME',
                                  hint: 'Enter your username',
                                  icon: Icons.person_outline_rounded,
                                  onChanged: (v) => _username = v,
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 20),
                                _buildField(
                                  label: 'PASSWORD',
                                  hint: 'Enter your password',
                                  icon: Icons.lock_outline_rounded,
                                  onChanged: (v) => _password = v,
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                  obscure: _obscurePassword,
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white.withOpacity(0.3),
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            final String result =
                                                await Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                ).login(_username, _password);
                                            if (mounted) {
                                              if (result == 'Success') {
                                                Navigator.of(
                                                  context,
                                                ).pushReplacement(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const Dashboard(),
                                                  ),
                                                );
                                              } else {
                                                _showSnackBar(
                                                  result == 'NotCorrect'
                                                      ? 'Invalid username or password.'
                                                      : result ==
                                                            'ResetPassword'
                                                      ? 'Password reset required.'
                                                      : result == 'Duplicate'
                                                      ? 'Duplicate user detected.'
                                                      : result == 'Attempt'
                                                      ? 'Too many attempts. Try again later.'
                                                      : 'Login error. Please try again.',
                                                  false,
                                                );
                                              }
                                            }
                                          }
                                        },
                                        child: Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF8f72ec),
                                                Color(0xFF5B3FD8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF8f72ec,
                                                ).withOpacity(0.4),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'SIGN IN',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _isAuthenticating
                                          ? null
                                          : _loginWithBiometric,
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF8f72ec,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF8f72ec,
                                            ).withOpacity(0.3),
                                          ),
                                        ),
                                        child: _isAuthenticating
                                            ? Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white
                                                            .withOpacity(0.6),
                                                      ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.fingerprint,
                                                size: 26,
                                                color: Color(0xFF8f72ec),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Register fingerprint via Enable Biometric in menu',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 10,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 24,
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ],
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
    );
  }

  Widget _ring(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(opacity), width: 1),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF8f72ec).withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          obscureText: obscure,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.18),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(icon, color: Colors.white.withOpacity(0.2), size: 18),
            ),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffix,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF8f72ec),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE05555)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE05555)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }
}
