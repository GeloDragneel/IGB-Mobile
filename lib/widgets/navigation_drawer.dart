import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

// Dark palette (same as the web sidebar)
const _panel = Color(0xFF111827);
const _bg = Color(0xFF1F2937); // header card
const _ink = Colors.white;
const _muted = Color(0xFF94A3B8);
const _faint = Color(0xFF7C8BB0); // section labels
const _icon = Color(0xFFCBD5E1);
const _line = Color(0x1FFFFFFF);
const _indigo = Color(0xFF5B6AF0);
const _indigoText = Color(0xFFA5B4FC);
const _green = Color(0xFF34D399);
const _red = Color(0xFFF87171);

String _ym(String v) {
  const m = [
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
  final p = v.split('-');
  if (p.length < 2) return v;
  final i = (int.tryParse(p[1]) ?? 0) - 1;
  return i >= 0 && i < 12 ? '${m[i]} ${p[0]}' : v;
}

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  const AppDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final loc = AppLocalizations.of(context);
    final isUser2 = auth.userCount == "User2";
    final canCash =
        isUser2 &&
        (auth.designationId == "1" ||
            auth.designationId == "6" ||
            auth.designationId == "7");

    final title = auth.tradeName.isNotEmpty ? auth.tradeName : auth.position;
    final initial = title.isNotEmpty ? title[0].toUpperCase() : 'U';

    void go(String route) => Navigator.pushReplacementNamed(context, route);

    return Drawer(
      backgroundColor: _panel,
      surfaceTintColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), _indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (!isUser2)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Material(
                  color: _green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => go('/accountingPeriod'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: _green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${_ym(auth.fromDate)} to ${_ym(auth.toDate)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Menu ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                children: [
                  if (!isUser2) ...[
                    _section('Main'),
                    _item(
                      Icons.home_outlined,
                      loc.dashboard,
                      selectedIndex == 0,
                      () => go('/dashboard'),
                    ),
                    _item(
                      Icons.point_of_sale_outlined,
                      loc.sales,
                      selectedIndex == 3,
                      () => go('/sales'),
                    ),
                    _item(
                      Icons.shopping_cart_outlined,
                      loc.purchases,
                      selectedIndex == 4,
                      () => go('/purchases'),
                    ),
                    _item(
                      Icons.receipt_long_outlined,
                      loc.expenses,
                      selectedIndex == 5,
                      () => go('/expenses'),
                    ),
                    _section('Account'),
                    _item(
                      Icons.person_outline_rounded,
                      loc.profile,
                      selectedIndex == 1,
                      () => go('/profile'),
                    ),
                    _item(
                      Icons.calendar_month_outlined,
                      loc.accountingPeriod,
                      selectedIndex == 2,
                      () => go('/accountingPeriod'),
                    ),
                  ],
                  if (isUser2) ...[
                    _section('Main'),
                    _item(
                      Icons.calendar_month_outlined,
                      loc.calendar,
                      selectedIndex == 2,
                      () => go('/calendar'),
                    ),
                    // staff profile (HR record) — clients keep /profile above
                    _item(
                      Icons.person_outline_rounded,
                      loc.profile,
                      selectedIndex == 8,
                      () => go('/myProfile'),
                    ),
                  ],
                  /*
                  if (canCash) ...[
                    _item(
                      Icons.payment_outlined,
                      loc.payment,
                      selectedIndex == 2,
                      () => go('/payment'),
                    ),
                    _item(
                      Icons.payments_outlined,
                      loc.collection,
                      selectedIndex == 2,
                      () => go('/collection'),
                    ),
                    _item(
                      Icons.account_balance_wallet_outlined,
                      loc.deposit,
                      selectedIndex == 2,
                      () => go('/deposit'),
                    ),
                  ],
                  */
                  _section('Settings'),
                  _item(
                    Icons.fingerprint,
                    loc.enableBiometric,
                    selectedIndex == 7,
                    () => go('/biometric'),
                  ),
                  _item(
                    Icons.language_outlined,
                    localeProvider.languageName,
                    false,
                    () => _showLanguageDialog(context, localeProvider),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        localeProvider.languageCode.toUpperCase(),
                        style: const TextStyle(
                          color: _indigoText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Logout ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Material(
                color: _red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    auth.logout();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: _red, size: 20),
                        const SizedBox(width: 14),
                        Text(
                          loc.logout,
                          style: const TextStyle(
                            color: _red,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: _faint,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? _indigo : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? Colors.white : _icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    Widget option(String name, String code, bool on, String set) {
      return Material(
        color: on ? _indigo.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            localeProvider.setLanguageCode(set);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  on ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: on ? _indigoText : _faint,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  code,
                  style: const TextStyle(
                    color: _muted,
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _panel,
          surfaceTintColor: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Language',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option('English', 'EN', localeProvider.isEnglish, 'en'),
              const SizedBox(height: 4),
              option('中文', 'CN', localeProvider.isChinese, 'zh'),
            ],
          ),
        );
      },
    );
  }
}
