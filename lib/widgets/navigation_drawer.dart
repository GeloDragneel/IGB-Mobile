import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  const AppDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Color(0xFF0e1726)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      auth.tradeName.isNotEmpty
                          ? auth.tradeName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.tradeName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          auth.fullName,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.home, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).dashboard,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 0,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.attach_money, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).sales,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 3,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/sales');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_cart, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).purchases,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 4,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/purchases');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.receipt, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).expenses,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 5,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/expenses');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.report, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).reports,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 6,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/reports');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).profile,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 1,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/profile');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.calendar_month, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).accountingPeriod,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 2,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/accountingPeriod',
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.fingerprint, color: Colors.white),
                    title: Text(
                      AppLocalizations.of(context).enableBiometric,
                      style: TextStyle(color: Colors.white),
                    ),
                    selected: selectedIndex == 7,
                    selectedTileColor: Color(0xFF101222),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/biometric');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.language, color: Colors.white),
                    title: Text(
                      localeProvider.languageCode,
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      localeProvider.languageName,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    onTap: () {
                      _showLanguageDialog(context, localeProvider);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[700]),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.white),
              title: Text(
                AppLocalizations.of(context).logout,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                auth.logout();
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0e1726),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  localeProvider.isEnglish
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: localeProvider.isEnglish
                      ? Colors.blue
                      : Colors.white70,
                ),
                title: const Text(
                  'English',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'EN',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  localeProvider.setLanguageCode('en');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  localeProvider.isChinese
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: localeProvider.isChinese
                      ? Colors.blue
                      : Colors.white70,
                ),
                title: const Text('中文', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'CN',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  localeProvider.setLanguageCode('zh');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
