import 'package:flutter/material.dart';

/// Same look as the web Messenger (Messenger.css, FB style)
class MC {
  static const bg = Colors.white;
  static const soft = Color(0xFFF0F2F5);
  static const hover = Color(0xFFF2F3F5);
  static const line = Color(0xFFE4E6EB);
  static const ink = Color(0xFF050505);
  static const muted = Color(0xFF65676B);
  static const faint = Color(0xFF8A8D91);
  static const blue = Color(0xFF0866FF);
  static const theirs = Color(0xFFF0F0F0);
  static const green = Color(0xFF31A24C);
  static const red = Color(0xFFE41E3F);
}

/* ---------- chat themes (keys = MessengerController::THEMES, same colours as Messenger.jsx) ---------- */
class MTheme {
  final List<Color> mine;
  final Color accent;
  final bool vertical;
  const MTheme(this.mine, this.accent, [this.vertical = false]);
  LinearGradient get gradient => LinearGradient(
    colors: mine,
    begin: vertical ? Alignment.topCenter : Alignment.topLeft,
    end: vertical ? Alignment.bottomCenter : Alignment.bottomRight,
  );
}

const mThemes = <String, MTheme>{
  'default': MTheme(
    [Color(0xFF0A7CFF), Color(0xFF0866FF)],
    Color(0xFF0866FF),
    true,
  ),
  'ocean': MTheme([Color(0xFF00C6FF), Color(0xFF0072FF)], Color(0xFF0072FF)),
  'berry': MTheme([Color(0xFFFF5EA8), Color(0xFFA445FF)], Color(0xFFC23BFF)),
  'sunset': MTheme([Color(0xFFFFB347), Color(0xFFFF5F6D)], Color(0xFFF2545B)),
  'forest': MTheme([Color(0xFF3FBF6F), Color(0xFF12855A)], Color(0xFF16935F)),
  'grape': MTheme([Color(0xFF8F6BFF), Color(0xFF5B2BD6)], Color(0xFF6A3DF0)),
  'rose': MTheme([Color(0xFFFF8FA3), Color(0xFFE0245E)], Color(0xFFE0245E)),
  'teal': MTheme([Color(0xFF2DD4BF), Color(0xFF0D9488)], Color(0xFF0D9488)),
  'tangerine': MTheme([
    Color(0xFFFFA53A),
    Color(0xFFF76B1C),
  ], Color(0xFFF2711C)),
  'midnight': MTheme([Color(0xFF475569), Color(0xFF0F172A)], Color(0xFF334155)),
  'igb': MTheme([
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFD946EF),
  ], Color(0xFF7C3AED)),
};
MTheme mThemeOf(dynamic key) => mThemes['${key ?? ''}'] ?? mThemes['default']!;

/* ---------- chat backgrounds (keys = MessengerController::BACKGROUNDS) ---------- */
class MBg {
  final Color color;
  final Gradient? gradient;
  final bool dark;
  const MBg(this.color, {this.gradient, this.dark = false});
  BoxDecoration get deco => BoxDecoration(color: color, gradient: gradient);
}

const mBackgrounds = <String, MBg>{
  'none': MBg(Colors.white),
  'sky': MBg(
    Color(0xFFF5FBFF),
    gradient: LinearGradient(
      colors: [Color(0xFFE0F2FF), Color(0xFFF5FBFF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  'blush': MBg(
    Color(0xFFFFF6F8),
    gradient: LinearGradient(
      colors: [Color(0xFFFFE4EC), Color(0xFFFFF6F8)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  'mint': MBg(
    Color(0xFFF3FFF7),
    gradient: LinearGradient(
      colors: [Color(0xFFDCFCE7), Color(0xFFF3FFF7)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  'sand': MBg(
    Color(0xFFFFFAF0),
    gradient: LinearGradient(
      colors: [Color(0xFFFDF0D5), Color(0xFFFFFAF0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  'lavender': MBg(
    Color(0xFFFAF8FF),
    gradient: LinearGradient(
      colors: [Color(0xFFEDE9FE), Color(0xFFFAF8FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  'aurora': MBg(
    Color(0xFFF8FAFC),
    gradient: LinearGradient(
      colors: [Color(0xFFC7F9E9), Color(0xFFDBE4FF), Color(0xFFFDE2F3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  'peach': MBg(
    Color(0xFFFFECD2),
    gradient: LinearGradient(
      colors: [Color(0xFFFFECD2), Color(0xFFFCB69F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  'dots': MBg(Color(0xFFF7F8FA)),
  'grid': MBg(Color(0xFFFBFCFE)),
  'waves': MBg(Color(0xFFF4F8FF)),
  'night': MBg(
    Color(0xFF0F172A),
    gradient: LinearGradient(
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    dark: true,
  ),
  'galaxy': MBg(
    Color(0xFF0B1020),
    gradient: LinearGradient(
      colors: [Color(0xFF4C1D95), Color(0xFF0B1020), Color(0xFF1E3A8A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dark: true,
  ),
};
MBg mBgOf(dynamic key) => mBackgrounds['${key ?? ''}'] ?? mBackgrounds['none']!;

/* ---------- time: always Philippine time, like the web ---------- */
DateTime _ph(DateTime d) => d.isUtc
    ? d.add(const Duration(hours: 8))
    : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
DateTime _nowPh() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime? mParse(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse('$v'.replaceFirst(' ', 'T'));
  return d == null ? null : _ph(d);
}

const _mons = [
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
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "now", "5m", "3h", "Fri", "Oct 28"
String mAgo(dynamic v) {
  final d = mParse(v);
  if (d == null) return '';
  final s = _nowPh().difference(d).inSeconds;
  if (s < 60) return 'now';
  if (s < 3600) return '${s ~/ 60}m';
  if (s < 86400) return '${s ~/ 3600}h';
  if (s < 7 * 86400) return _days[d.weekday - 1];
  return '${_mons[d.month - 1]} ${d.day}';
}

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// today → "4:52 PM", else "Oct 28, 4:52 PM"
String mStamp(dynamic v) {
  final d = mParse(v);
  if (d == null) return '';
  final n = _nowPh();
  final today = n.year == d.year && n.month == d.month && n.day == d.day;
  return today ? _clock(d) : '${_mons[d.month - 1]} ${d.day}, ${_clock(d)}';
}

String mActive(dynamic p) {
  if (p == null) return '';
  if (p['online'] == true) return 'Active now';
  if (p['last_seen'] != null)
    return 'Active ${mAgo(p['last_seen'])} ago'.replaceAll(
      'now ago',
      'just now',
    );
  return '';
}

String mSize(dynamic bytes) {
  final b = bytes is num ? bytes.toDouble() : double.tryParse('$bytes') ?? 0;
  if (b <= 0) return '';
  if (b < 1024) return '${b.toInt()} B';
  if (b < 1048576) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1048576).toStringAsFixed(1)} MB';
}

String mFirst(dynamic n) => '${n ?? ''}'.trim().split(RegExp(r'\s+')).first;

/* ---------- stable photo links ----------
   The server signs every S3 link again on each request (new ?X-Amz-... each time), so the same photo got a new
   URL every refresh and Flutter reloaded it = blinking. Keep the first link of each file for 90 min (they last 2 h). */
final Map<String, MapEntry<String, DateTime>> _photoCache = {};
String? mPhoto(dynamic url) {
  if (url == null) return null;
  final u = '$url';
  if (u.isEmpty) return null;
  final key = u.split('?').first;
  final hit = _photoCache[key];
  if (hit != null && DateTime.now().difference(hit.value).inMinutes < 90)
    return hit.key;
  _photoCache[key] = MapEntry(u, DateTime.now());
  return u;
}

/* ---------- avatars: same colours / initials as the web ---------- */
const _colors = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
  Color(0xFF16A34A),
  Color(0xFF0891B2),
  Color(0xFF4F46E5),
  Color(0xFFBE123C),
];
Color mColorOf(String n) =>
    _colors[n.codeUnits.fold<int>(0, (a, c) => a + c) % _colors.length];
String mInitials(String n) {
  final w = n
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .take(2)
      .map((e) => e[0])
      .join()
      .toUpperCase();
  return w.isEmpty ? '?' : w;
}

class MAvatar extends StatelessWidget {
  final String name;
  final String? photo;
  final double size;
  final bool online;
  final bool ring; // white ring (group avatars)
  const MAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 36,
    this.online = false,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = mPhoto(photo);
    final has = url != null;
    final dot = size * 0.28 < 10 ? 10.0 : size * 0.28;
    final initials = Text(
      mInitials(name),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.38,
        height: 1,
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mColorOf(name),
              shape: BoxShape.circle,
              border: ring ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: has
                ? ClipOval(
                    child: Image.network(
                      url,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Center(child: initials),
                    ),
                  )
                : initials,
          ),
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: MC.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// a chat's avatar: the other person, or two overlapping faces for a group (like ConvAvatar)
class MConvAvatar extends StatelessWidget {
  final Map c;
  final double size;
  final bool? online;
  const MConvAvatar({super.key, required this.c, this.size = 40, this.online});

  @override
  Widget build(BuildContext context) {
    final on = online ?? (c['online'] == true);
    if (c['is_group'] != true) {
      final o = c['other'];
      return MAvatar(
        name: '${o?['name'] ?? c['name'] ?? ''}',
        photo: o?['photo'],
        size: size,
        online: on,
      );
    }
    final av = (c['avatars'] as List?) ?? [];
    final a = av.isNotEmpty ? av[0] : null;
    final b = av.length > 1 ? av[1] : null;
    final s = size * 0.68;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: MAvatar(
              name: '${b?['name'] ?? c['name'] ?? ''}',
              photo: b?['photo'],
              size: s,
              ring: true,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: MAvatar(
              name: '${a?['name'] ?? c['name'] ?? ''}',
              photo: a?['photo'],
              size: s,
              ring: true,
            ),
          ),
          if (on)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: MC.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------- file badge: coloured like the web ---------- */
const _fileColors = <String, Color>{
  'pdf': Color(0xFFE5252A),
  'doc': Color(0xFF2B579A),
  'docx': Color(0xFF2B579A),
  'xls': Color(0xFF217346),
  'xlsx': Color(0xFF217346),
  'csv': Color(0xFF217346),
  'ppt': Color(0xFFD24726),
  'pptx': Color(0xFFD24726),
  'zip': Color(0xFF7C5CFF),
  'rar': Color(0xFF7C5CFF),
  '7z': Color(0xFF7C5CFF),
};

class MFileBadge extends StatelessWidget {
  final String name;
  final double size;
  const MFileBadge({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fileColors[ext] ?? const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (ext.isEmpty ? 'FILE' : ext).toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * (ext.length > 3 ? 0.24 : 0.3),
        ),
      ),
    );
  }
}

/// round grey button like .ms-circle
class MCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tip;
  const MCircle({super.key, required this.icon, required this.onTap, this.tip});

  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: MC.soft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 19, color: MC.ink),
        ),
      ),
    );
    return tip == null ? b : Tooltip(message: tip!, child: b);
  }
}

/// grey pill search box like .ms-search
class MSearch extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  const MSearch({
    super.key,
    this.controller,
    this.hint = 'Search Messenger',
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MC.soft,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: MC.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: autofocus,
              style: const TextStyle(color: MC.ink, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: MC.muted, fontSize: 15),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void mSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? MC.red : MC.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );
}
