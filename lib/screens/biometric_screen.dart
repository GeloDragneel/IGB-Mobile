import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navigation_drawer.dart';
import '../l10n/app_localizations.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isBiometricAvailable = false;
  bool _isFingerprintRegistered = false;
  bool _isAuthenticating = false;

  static const String _storageCAIDsKey = 'biometric_caids';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkBiometricAvailability();
    _checkFingerprintRegistration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canAuthenticate =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      setState(() => _isBiometricAvailable = canAuthenticate);
    } catch (e) {
      setState(() => _isBiometricAvailable = false);
    }
  }

  Future<void> _checkFingerprintRegistration() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final key = '${authProvider.comId}_${authProvider.userId}';

      final response = await http.get(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/biometric_validation.php'
          '?keys=$key',
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isRegistered = data['result'] == 'Success';

        if (isRegistered) {
          final prefs = await SharedPreferences.getInstance();
          final storedCAIDs = prefs.getString(_storageCAIDsKey) ?? '';
          final caidList = storedCAIDs.isNotEmpty
              ? storedCAIDs.split(',')
              : <String>[];
          if (!caidList.contains(key)) {
            caidList.add(key);
            await prefs.setString(_storageCAIDsKey, caidList.join(','));
          }
        }

        setState(() => _isFingerprintRegistered = isRegistered);
      }
    } catch (e) {
      debugPrint('Server check failed, falling back to local: $e');
      await _checkFingerprintRegistrationLocally();
    }
  }

  Future<void> _checkFingerprintRegistrationLocally() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final storedCAIDs = prefs.getString(_storageCAIDsKey) ?? '';
      final caidList = storedCAIDs.isNotEmpty
          ? storedCAIDs.split(',')
          : <String>[];
      final key = '${authProvider.comId}_${authProvider.userId}';
      if (mounted)
        setState(() => _isFingerprintRegistered = caidList.contains(key));
    } catch (e) {
      debugPrint('Local fingerprint check error: $e');
      if (mounted) setState(() => _isFingerprintRegistered = false);
    }
  }

  Future<void> _saveKeyLocally(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storedCAIDs = prefs.getString(_storageCAIDsKey) ?? '';
    final caidList = storedCAIDs.isNotEmpty
        ? storedCAIDs.split(',')
        : <String>[];
    if (!caidList.contains(key)) {
      caidList.add(key);
      await prefs.setString(_storageCAIDsKey, caidList.join(','));
    }
  }

  Future<void> _registerFingerprint() async {
    if (!_isBiometricAvailable) {
      _showSnackBar(
        AppLocalizations.of(context).biometricAuthentificationNotAvail,
        false,
      );
      return;
    }

    setState(() => _isAuthenticating = true);
    final loc = AppLocalizations.of(context);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to register your fingerprint',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated || !mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.isLoggedIn) {
        _showSnackBar(AppLocalizations.of(context).pleaseLoginFirst, false);
        return;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fingerprintData =
          'FP_${timestamp}_CAID_${authProvider.comId}_USER_${authProvider.userId}';

      final response = await http.post(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/biometric_registration.php',
        ),
        body: {
          'CAID': authProvider.comId,
          'UserID': authProvider.userId,
          'FingerprintData': fingerprintData,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final key = '${authProvider.comId}_${authProvider.userId}';

        if (data['result'] == 'Success') {
          await _saveKeyLocally(key);
          setState(() => _isFingerprintRegistered = true);
          _showSnackBar(loc.fingerprintRegisteredSuccess, true);
        } else if (data['result'] == 'Error' &&
            data['message'] == 'Biometric already registered') {
          await _saveKeyLocally(key);
          setState(() => _isFingerprintRegistered = true);
          _showSnackBar(loc.enableBiometric, false);
        } else {
          _showSnackBar('${loc.registrationFailed}: ${data['message']}', false);
        }
      } else {
        _showSnackBar(loc.serverError, false);
      }
    } catch (e) {
      if (mounted) _showSnackBar('${loc.registrationFailed}: $e', false);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e1726),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).enableBiometric),
        backgroundColor: const Color(0xFF0e1726),
        elevation: 0,
      ),
      drawer: AppDrawer(selectedIndex: 6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isFingerprintRegistered
                  ? AppLocalizations.of(context).fingerprintRegistered
                  : AppLocalizations.of(context).notRegistered,
              style: TextStyle(
                color: _isFingerprintRegistered
                    ? const Color(0xFF8f72ec)
                    : Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isAuthenticating || _isFingerprintRegistered
                  ? null
                  : _registerFingerprint,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isFingerprintRegistered ? 1.0 : _pulseAnim.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF151f30),
                    border: Border.all(
                      color: _isFingerprintRegistered
                          ? const Color(0xFF8f72ec)
                          : Colors.grey[700]!,
                      width: 2,
                    ),
                    boxShadow: _isFingerprintRegistered
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8f72ec).withOpacity(0.35),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: _isAuthenticating
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8f72ec),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          Icons.fingerprint,
                          size: 120,
                          color: _isFingerprintRegistered
                              ? const Color(0xFF8f72ec)
                              : Colors.grey[600],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isFingerprintRegistered
                  ? AppLocalizations.of(context).yourFingerPrintIsActive
                  : AppLocalizations.of(context).tapToRegisterYourFingerPrint,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 60),
            if (!_isFingerprintRegistered)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8f72ec),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isAuthenticating ? null : _registerFingerprint,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      AppLocalizations.of(context).registerFingerprint,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
