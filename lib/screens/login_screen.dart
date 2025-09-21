import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF101222),
            // borderRadius: BorderRadius.circular(16),
            // border: Border.all(color: const Color(0xFF23243a), width: 1), // REMOVED
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.grey[100],
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your username and password to login.',
                  style: TextStyle(color: Colors.grey[300], fontSize: 15),
                ),
                const SizedBox(height: 28),
                Text(
                  'Username',
                  style: TextStyle(
                    color: Colors.grey[400],
                    letterSpacing: 2,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF202B40),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 14,
                    ),
                  ),
                  onChanged: (val) => _username = val,
                  validator: (val) => val!.isEmpty ? 'Enter username' : null,
                ),
                const SizedBox(height: 20),
                Text(
                  'Password',
                  style: TextStyle(
                    color: Colors.grey[400],
                    letterSpacing: 2,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF202B40),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 14,
                    ),
                  ),
                  obscureText: true,
                  onChanged: (val) => _password = val,
                  validator: (val) => val!.isEmpty ? 'Enter password' : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      backgroundColor: const Color(0xFF8f72ec), // purple
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        String result = await Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).login(_username, _password);

                        if (mounted) {
                          switch (result) {
                            case 'Success':
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Login successful!')),
                              );
                              // Navigate to next screen here
                              break;

                            case 'NotCorrect':
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Invalid username or password.',
                                  ),
                                ),
                              );
                              break;

                            case 'ResetPassword':
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Password reset required.'),
                                ),
                              );
                              // Navigate to reset password screen or show dialog
                              break;

                            case 'Duplicate':
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Duplicate user detected. Contact support.',
                                  ),
                                ),
                              );
                              break;

                            case 'Attempt':
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Too many attempts. Try again later.',
                                  ),
                                ),
                              );
                              break;

                            default:
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Login error. Please try again.',
                                  ),
                                ),
                              );
                          }
                        }
                      }
                    },

                    child: const Text('SIGN IN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
