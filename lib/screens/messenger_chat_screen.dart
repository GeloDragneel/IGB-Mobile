import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/messenger_api.dart';
import '../widgets/messenger_ui.dart';
import 'messenger_info_screen.dart';

/// One chat – same look and actions as the web Messenger window (Messenger.jsx → ChatWindow)
class MessengerChatScreen extends StatefulWidget {
  final int conversationId;
  final String title;
  const MessengerChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<MessengerChatScreen> createState() => _MessengerChatScreenState();
}

class _MessengerChatScreenState extends State<MessengerChatScreen> {
  static const _reactions = ['❤️', '😆', '😮', '😢', '😠', '👍'];
  static const _emoji = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '😘',
    '😋',
    '😜',
    '🤪',
    '🤗',
    '🤔',
    '🤐',
    '😐',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😌',
    '😔',
    '😴',
    '😷',
    '🥵',
    '🥶',
    '😎',
    '🤓',
    '😕',
    '😟',
    '😮',
    '😲',
    '🥺',
    '😢',
    '😭',
    '😱',
    '😤',
    '😡',
    '😠',
    '🤬',
    '💀',
    '🤡',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🙏',
    '💪',
    '👌',
    '✌️',
    '🤞',
    '👋',
    '🤝',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '💯',
    '🔥',
    '✨',
    '🎉',
    '🎂',
    '🎁',
    '✅',
    '❌',
    '⚠️',
    '📌',
    '📎',
    '📄',
    '💰',
    '☕',
  ];
  static const _docExt = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'csv',
    'txt',
    'ppt',
    'pptx',
    'zip',
    'rar',
    '7z',
    'odt',
    'ods',
    'rtf',
    'xml',
    'json',
  ];

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  Map<String, dynamic>? _conv;
  List<dynamic> _members = [];
  List<dynamic> _pinned = [];
  final List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _showTools = false;
  int _pinIdx = 0;
  Map<String, dynamic>? _replyTo;
  Timer? _poll;
  DateTime _lastTyping = DateTime(2000);
  int _readSent = 0;
  String _sideSig = '';
  // search in this conversation
  bool _searchOpen = false;
  final _sq = TextEditingController();
  List<dynamic>? _hits;
  Timer? _searchT;
  // jump to a message
  final Map<int, GlobalKey> _keys = {};
  int? _flash;

  int get _cid => widget.conversationId;
  bool get _group => _conv?['is_group'] == true;
  MTheme get _theme => mThemeOf(_conv?['theme']);
  MBg get _bg => mBgOf(_conv?['background']);

  int get _lastId {
    var m = 0;
    for (final x in _msgs) {
      final id = x['id'];
      if (id is int && id > m) m = id;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 200)
        _loadOlder();
    });
    _text.addListener(() {
      if (_text.text.isEmpty && _showTools) _showTools = false;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchT?.cancel();
    _sq.dispose();
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _rows(dynamic v) =>
      ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

  // members' read marks + pinned list: only redraw when they change (no blinking)
  String _sideSignature(dynamic members, dynamic pinned) =>
      '${((members as List?) ?? []).map((m) => '${m['id']}:${m['last_read_id']}:${m['online']}').join(',')}|'
      '${((pinned as List?) ?? []).map((p) => p['id']).join(',')}';

  Future<void> _load() async {
    try {
      final d = await MessengerApi.get('conversations/$_cid');
      if (!mounted) return;
      setState(() {
        _conv = Map<String, dynamic>.from(d['conversation']);
        _members = (d['members'] as List?) ?? [];
        _pinned = (d['pinned'] as List?) ?? [];
        _sideSig = _sideSignature(_members, _pinned);
        _msgs
          ..clear()
          ..addAll(_rows(d['messages']));
        _hasMore = d['has_more'] == true;
        _loading = false;
      });
      _markRead();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollNew());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      mSnack(context, e.toString(), error: true);
    }
  }

  // a show() payload from the server (customize, rename, members, pin…) → update this chat
  void _applyPayload(Map<String, dynamic> d) {
    if (!mounted) return;
    final last = _lastId;
    setState(() {
      if (d['conversation'] != null)
        _conv = Map<String, dynamic>.from(d['conversation']);
      if (d['members'] != null) _members = List.from(d['members']);
      if (d['pinned'] != null) _pinned = List.from(d['pinned']);
      _sideSig = _sideSignature(_members, _pinned);
      for (final m in _rows(d['messages'])) {
        final i = _msgs.indexWhere((x) => x['id'] == m['id']);
        if (i >= 0) {
          _msgs[i] = m;
        } else if ((m['id'] as int) > last) {
          _msgs.add(m);
        }
      }
      if (_pinIdx >= _pinned.length) _pinIdx = 0;
    });
  }

  Future<void> _pollNew({bool force = false}) async {
    try {
      final d = await MessengerApi.get('conversations/$_cid', {
        'after_id': '$_lastId',
      });
      if (!mounted) return;
      final fresh = _rows(
        d['messages'],
      ).where((m) => !_msgs.any((x) => x['id'] == m['id'])).toList();
      final changed = _rows(d['changed']);
      final unsent = ((d['unsent'] as List?) ?? [])
          .map((e) => e as int)
          .toSet();
      final side = _sideSignature(d['members'], d['pinned']);
      final conv = Map<String, dynamic>.from(d['conversation']);
      final convChanged =
          '${conv['name']}|${conv['theme']}|${conv['background']}|${conv['emoji']}|${conv['other']?['online']}' !=
          '${_conv?['name']}|${_conv?['theme']}|${_conv?['background']}|${_conv?['emoji']}|${_conv?['other']?['online']}';
      if (!force &&
          fresh.isEmpty &&
          changed.isEmpty &&
          unsent.isEmpty &&
          side == _sideSig &&
          !convChanged)
        return;
      setState(() {
        _conv = conv;
        _members = (d['members'] as List?) ?? _members;
        _pinned = (d['pinned'] as List?) ?? _pinned;
        _sideSig = side;
        _msgs.addAll(fresh);
        for (final m in changed) {
          final i = _msgs.indexWhere((x) => x['id'] == m['id']);
          if (i >= 0) _msgs[i] = m;
        }
        for (var i = 0; i < _msgs.length; i++) {
          if (unsent.contains(_msgs[i]['id']))
            _msgs[i] = {
              ..._msgs[i],
              'unsent': true,
              'body': null,
              'image': null,
              'file': null,
            };
        }
      });
      if (fresh.isNotEmpty) _markRead();
    } catch (_) {}
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingOlder || _msgs.isEmpty) return;
    _loadingOlder = true;
    try {
      final first = _msgs
          .map((e) => e['id'])
          .whereType<int>()
          .reduce((a, b) => a < b ? a : b);
      final d = await MessengerApi.get('conversations/$_cid', {
        'before_id': '$first',
      });
      if (!mounted) return;
      final older = _rows(d['messages']);
      setState(() {
        _msgs.insertAll(
          0,
          older.where((m) => !_msgs.any((x) => x['id'] == m['id'])),
        );
        _hasMore = d['has_more'] == true;
      });
    } catch (_) {}
    _loadingOlder = false;
  }

  Future<void> _markRead() async {
    final id = _lastId;
    if (id <= 0 || id <= _readSent) return;
    _readSent = id;
    try {
      await MessengerApi.post('conversations/$_cid/read', {'message_id': id});
    } catch (_) {}
  }

  void _typing() {
    if (DateTime.now().difference(_lastTyping).inSeconds < 4) return;
    _lastTyping = DateTime.now();
    MessengerApi.post('conversations/$_cid/typing').catchError((_) => null);
  }

  Future<void> _send({
    String? body,
    String? sticker,
    String? gif,
    List<File> images = const [],
    List<PlatformFile> files = const [],
  }) async {
    final text =
        body ??
        (sticker == null && gif == null && images.isEmpty && files.isEmpty
            ? _text.text
            : '');
    if (text.trim().isEmpty &&
        sticker == null &&
        gif == null &&
        images.isEmpty &&
        files.isEmpty)
      return;
    setState(() => _sending = true);
    try {
      final d = await MessengerApi.send(
        _cid,
        body: text,
        sticker: sticker,
        gif: gif,
        images: images,
        files: files,
        replyToId: _replyTo?['id'] as int?,
      );
      if (!mounted) return;
      final rows = _rows(d['messages']);
      setState(() {
        for (final m in rows) {
          if (!_msgs.any((x) => x['id'] == m['id'])) _msgs.add(m);
        }
        if (body == null && text.isNotEmpty) _text.clear();
        _replyTo = null;
        _showTools = false;
      });
      _readSent = _lastId;
      if (_scroll.hasClients)
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _react(Map m, String emoji) async {
    try {
      final d = await MessengerApi.post('messages/${m['id']}/react', {
        'emoji': emoji,
      });
      final i = _msgs.indexWhere((x) => x['id'] == m['id']);
      if (i >= 0 && mounted)
        setState(
          () => _msgs[i] = {..._msgs[i], 'reactions': d['reactions'] ?? []},
        );
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _unpinById(int id) => _pinMsg({'id': id}, false);

  Future<void> _pinMsg(Map m, bool on) async {
    try {
      final d = await MessengerApi.post('messages/${m['id']}/pin', {
        'pinned': on,
      });
      if (d is Map) _applyPayload(Map<String, dynamic>.from(d));
      final i = _msgs.indexWhere((x) => x['id'] == m['id']);
      if (i >= 0 && mounted)
        setState(() => _msgs[i] = {..._msgs[i], 'pinned': on});
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _unsend(Map m) async {
    try {
      await MessengerApi.post('messages/${m['id']}', null, 'DELETE');
      final i = _msgs.indexWhere((x) => x['id'] == m['id']);
      if (i >= 0 && mounted) {
        setState(
          () => _msgs[i] = {
            ..._msgs[i],
            'unsent': true,
            'body': null,
            'image': null,
            'file': null,
            'reactions': [],
          },
        );
      }
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
  }

  // ── Pickers ──────────────────────────────────────────────────
  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    _send(images: picked.take(10).map((x) => File(x.path)).toList());
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x != null) _send(images: [File(x.path)]);
  }

  Future<void> _pickFiles() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _docExt,
    );
    if (r == null || r.files.isEmpty) return;
    _send(files: r.files.take(10).toList());
  }

  void _sheet(Widget Function(BuildContext) child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(child: child(ctx)),
    );
  }

  Widget _emojiGrid(
    BuildContext ctx,
    void Function(String) onPick, {
    bool big = false,
  }) {
    return SizedBox(
      height: 300,
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(10),
        children: _emoji
            .map(
              (e) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.pop(ctx);
                  onPick(e);
                },
                child: Center(
                  child: Text(e, style: TextStyle(fontSize: big ? 28 : 22)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _insertEmoji(String e) {
    final sel = _text.selection;
    final t = _text.text;
    final a = sel.isValid ? sel.start : t.length;
    final b = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(
      text: t.replaceRange(a, b, e),
      selection: TextSelection.collapsed(offset: a + e.length),
    );
    _focus.requestFocus();
  }

  void _messageMenu(Map<String, dynamic> m) {
    if (m['type'] == 'system' || m['unsent'] == true || m['id'] is! int) return;
    final mine = m['mine'] == true;
    final myReacted = <String>{};
    for (final r in (m['reactions'] as List?) ?? []) {
      // ids of the people who reacted – mine is the one that's "me" in members
      final meId = _members.firstWhere(
        (x) => x['me'] == true,
        orElse: () => null,
      )?['id'];
      if (meId != null && ((r['ids'] as List?) ?? []).contains(meId))
        myReacted.add('${r['emoji']}');
    }
    _sheet(
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._reactions.map(
                  (e) => InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.pop(ctx);
                      _react(m, e);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: myReacted.contains(e)
                            ? MC.blue.withOpacity(0.14)
                            : Colors.transparent,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 27)),
                    ),
                  ),
                ),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sheet(
                      (c2) => _emojiGrid(c2, (e) => _react(m, e), big: true),
                    );
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: MC.soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: MC.muted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _menuItem(ctx, Icons.reply_rounded, 'Reply', () {
            setState(() => _replyTo = m);
            _focus.requestFocus();
          }),
          _menuItem(
            ctx,
            Icons.push_pin_outlined,
            m['pinned'] == true ? 'Unpin' : 'Pin',
            () => _pinMsg(m, m['pinned'] != true),
          ),
          _menuItem(ctx, Icons.shortcut_rounded, 'Forward', () => _forward(m)),
          if (m['type'] == 'text')
            _menuItem(ctx, Icons.copy_rounded, 'Copy text', () {
              Clipboard.setData(ClipboardData(text: '${m['body'] ?? ''}'));
              mSnack(context, 'Copied');
            }),
          if (m['type'] == 'file' && m['file'] != null)
            _menuItem(ctx, Icons.link_rounded, 'Copy download link', () {
              Clipboard.setData(ClipboardData(text: '${m['file']}'));
              mSnack(context, 'Link copied – paste it in your browser');
            }),
          if (mine)
            _menuItem(
              ctx,
              Icons.delete_outline_rounded,
              'Unsend',
              () => _unsend(m),
              danger: true,
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: danger ? MC.red : MC.ink),
      title: Text(
        label,
        style: TextStyle(
          color: danger ? MC.red : MC.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 12,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _info() {
    final c = _conv;
    if (c == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessengerInfoScreen(
          conversation: c,
          members: _members,
          pinned: _pinned,
          onPayload: _applyPayload,
          onJump: (id) => Future.delayed(
            const Duration(milliseconds: 250),
            () => _jumpTo(id),
          ),
          onSearch: () => setState(() => _searchOpen = true),
          onUnpinMessage: _unpinById,
          onOpenChat: (id, name) {
            if (id == _cid) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MessengerChatScreen(conversationId: id, title: name),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── search in this conversation ──────────────────────────────
  void _search(String q) {
    _searchT?.cancel();
    if (q.trim().length < 2) {
      setState(() => _hits = null);
      return;
    }
    _searchT = Timer(const Duration(milliseconds: 300), () async {
      try {
        final d = await MessengerApi.get('conversations/$_cid/search', {
          'q': q.trim(),
        });
        if (mounted) setState(() => _hits = (d['items'] as List?) ?? []);
      } catch (_) {
        if (mounted) setState(() => _hits = []);
      }
    });
  }

  void _closeSearch() {
    _searchT?.cancel();
    _sq.clear();
    setState(() {
      _searchOpen = false;
      _hits = null;
    });
  }

  // ── jump to a message (older pages are loaded until it's there), then flash it ──
  Future<void> _jumpTo(int id) async {
    for (
      var n = 0;
      n < 40 && _hasMore && !_msgs.any((m) => m['id'] == id);
      n++
    ) {
      while (_loadingOlder) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await _loadOlder();
    }
    if (!mounted) return;
    if (!_msgs.any((m) => m['id'] == id)) {
      mSnack(context, "Couldn't find that message.");
      return;
    }
    setState(() => _flash = id);
    for (var n = 0; n < 80; n++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
        break;
      }
      if (!_scroll.hasClients) break;
      final p = _scroll.position;
      final next = (p.pixels + p.viewportDimension * 0.8).clamp(
        0.0,
        p.maxScrollExtent,
      );
      if (next == p.pixels) break;
      _scroll.jumpTo(next);
    }
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _flash == id) setState(() => _flash = null);
    });
  }

  // ── forward a message to a chat or a person ──────────────────
  void _forward(Map m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ForwardSheet(message: m),
    );
  }

  // ── GIFs: GIPHY search / trending + the shared GIF library ───
  void _gifSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GifSheet(
        accent: _theme.accent,
        onPick: (url) {
          Navigator.pop(ctx);
          _send(gif: url);
        },
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────
  bool get _online => _group
      ? _members.any((m) => m['me'] != true && m['online'] == true)
      : _conv?['other']?['online'] == true;

  String get _status {
    if (_conv == null) return '';
    if (_group) {
      return '${_members.length} members${_members.any((m) => m['me'] != true && m['online'] == true) ? ' · some active' : ''}';
    }
    return mActive(_conv!['other']);
  }

  String _replyLabel(Map m) {
    final meId = _members.firstWhere(
      (x) => x['me'] == true,
      orElse: () => null,
    )?['id'];
    final mine = m['mine'] == true;
    final who = mine ? 'You' : mFirst(m['sender']);
    final r = m['reply'];
    final to = r['sender_id'] == meId
        ? (mine ? 'yourself' : 'you')
        : (r['sender_id'] == m['sender_id'] ? 'themself' : mFirst(r['sender']));
    return '$who replied to $to';
  }

  // who has seen up to which message (others only), like the web
  Map<int, List<dynamic>> get _seenAt {
    final map = <int, List<dynamic>>{};
    final ids = _msgs.map((m) => m['id']).whereType<int>().toList();
    for (final p in _members) {
      if (p['me'] == true) continue;
      final read = (p['last_read_id'] ?? 0) as int;
      int? at;
      for (final id in ids.reversed) {
        if (id <= read) {
          at = id;
          break;
        }
      }
      if (at != null) (map[at] ??= []).add(p);
    }
    return map;
  }

  bool _isBigEmoji(Map m) {
    if (m['type'] != 'text' || m['unsent'] == true) return false;
    final t = '${m['body'] ?? ''}'.trim();
    if (t.isEmpty || t.runes.length > 8) return false;
    return !RegExp(
      r'[A-Za-z0-9À-ɏ.,!?@#%&*()\-_=+\[\]{};:"<>/\\|`~^$]',
    ).hasMatch(t);
  }

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _conv;
    final name = '${c?['name'] ?? widget.title}';
    final accent = _theme.accent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: accent,
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          onTap: _info,
          child: Row(
            children: [
              if (c != null)
                MConvAvatar(c: c, size: 40, online: _online)
              else
                MAvatar(name: name, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MC.ink,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_status.isNotEmpty)
                      Text(
                        _status,
                        style: const TextStyle(color: MC.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: accent),
            onPressed: () => _searchOpen
                ? _closeSearch()
                : setState(() => _searchOpen = true),
          ),
          IconButton(
            icon: Icon(Icons.info_rounded, color: accent),
            onPressed: _info,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: MC.line),
        ),
      ),
      body: Column(
        children: [
          if (_pinned.isNotEmpty) _pinBar(),
          if (_searchOpen) _searchBar(),
          Expanded(
            child: Container(
              decoration: _bg.deco,
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      itemCount: _msgs.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _msgs.length) return _top();
                        final seen = _seenAt;
                        return _row(_msgs.length - 1 - i, seen);
                      },
                    ),
            ),
          ),
          if (_replyTo != null) _replyBar(),
          _composer(),
        ],
      ),
    );
  }

  Widget _top() {
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _theme.accent,
            ),
          ),
        ),
      );
    }
    final c = _conv;
    if (c == null) return const SizedBox.shrink();
    final dark = _bg.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 18),
      child: Column(
        children: [
          MConvAvatar(c: c, size: 64, online: _online),
          const SizedBox(height: 10),
          Text(
            '${c['name']}',
            style: TextStyle(
              color: dark ? Colors.white : MC.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _group
                ? '${_members.length} members'
                : "You're connected on IGB Messenger",
            style: TextStyle(
              color: dark ? Colors.white70 : MC.muted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinBar() {
    final p = _pinned[_pinIdx % _pinned.length];
    final icon = p['type'] == 'image'
        ? '📷 '
        : p['type'] == 'file'
        ? '📎 '
        : p['type'] == 'sticker'
        ? '🧩 '
        : p['type'] == 'gif'
        ? '🎞️ '
        : '';
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          _jumpTo(p['id'] as int);
          setState(() => _pinIdx = (_pinIdx + 1) % _pinned.length);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MC.line)),
          ),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: _theme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pinned${_pinned.length > 1 ? ' · ${_pinIdx % _pinned.length + 1} of ${_pinned.length}' : ''}',
                      style: const TextStyle(color: MC.muted, fontSize: 11.5),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: icon),
                          TextSpan(
                            text: '${mFirst(p['sender'])}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '${p['text'] ?? ''}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: MC.ink, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (_pinned.length > 1)
                TextButton(
                  onPressed: _info,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: _theme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: MC.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: MSearch(
                    controller: _sq,
                    hint: 'Search in conversation',
                    autofocus: true,
                    onChanged: _search,
                  ),
                ),
                if (_hits != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${_hits!.length >= 50 ? '50+' : _hits!.length} found',
                      style: const TextStyle(color: MC.muted, fontSize: 12),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: MC.muted),
                  onPressed: _closeSearch,
                ),
              ],
            ),
          ),
          if (_hits != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _hits!.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No messages found.',
                        style: TextStyle(color: MC.muted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _hits!.length,
                      itemBuilder: (_, i) {
                        final h = _hits![i];
                        return InkWell(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _jumpTo(h['id'] as int);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${h['sender'] ?? ''}',
                                        style: const TextStyle(
                                          color: MC.ink,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      mStamp(h['time']),
                                      style: const TextStyle(
                                        color: MC.muted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _highlight(
                                  '${h['type'] == 'file' ? '📎 ' : ''}${h['text'] ?? ''}',
                                  _sq.text.trim(),
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
    );
  }

  Widget _highlight(String text, String q) {
    if (q.isEmpty)
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: MC.muted, fontSize: 13),
      );
    final spans = <TextSpan>[];
    final low = text.toLowerCase();
    final ql = q.toLowerCase();
    var i = 0;
    while (true) {
      final j = low.indexOf(ql, i);
      if (j < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (j > i) spans.add(TextSpan(text: text.substring(i, j)));
      spans.add(
        TextSpan(
          text: text.substring(j, j + q.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFF3A3),
            color: MC.ink,
          ),
        ),
      );
      i = j + q.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: MC.muted, fontSize: 13),
    );
  }

  Widget _row(int idx, Map<int, List<dynamic>> seenAt) {
    final m = _msgs[idx];
    final prev = idx > 0 ? _msgs[idx - 1] : null;
    final next = idx < _msgs.length - 1 ? _msgs[idx + 1] : null;
    final t = mParse(m['time']);
    final pt = prev != null ? mParse(prev['time']) : null;
    final nt = next != null ? mParse(next['time']) : null;
    final gap =
        prev == null ||
        t == null ||
        pt == null ||
        t.difference(pt).inMinutes > 15;
    final dark = _bg.dark;
    final label = dark ? Colors.white70 : MC.muted;

    final timeRow = gap
        ? Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: Center(
              child: Text(
                mStamp(m['time']),
                style: TextStyle(
                  color: label,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (m['type'] == 'system') {
      return Column(
        children: [
          timeRow,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '${m['body'] ?? ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: label, fontSize: 12),
            ),
          ),
        ],
      );
    }

    final own = m['mine'] == true;
    final firstOfRun =
        gap ||
        prev == null ||
        prev['sender_id'] != m['sender_id'] ||
        prev['type'] == 'system';
    final lastOfRun =
        next == null ||
        next['sender_id'] != m['sender_id'] ||
        next['type'] == 'system' ||
        (nt != null && t != null && nt.difference(t).inMinutes > 15);
    final reactions = (m['reactions'] as List?) ?? [];
    final total = reactions.fold<int>(
      0,
      (a, r) => a + ((r['count'] ?? 1) as int),
    );
    final maxW = MediaQuery.of(context).size.width * 0.72;
    final seen = m['id'] is int ? seenAt[m['id']] : null;

    final key = m['id'] is int ? (_keys[m['id'] as int] ??= GlobalKey()) : null;
    final flashed = _flash != null && _flash == m['id'];

    return Column(
      key: key,
      crossAxisAlignment: own
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        timeRow,
        if (_group && !own && firstOfRun)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 6, 0, 2),
            child: Text(
              mFirst(m['sender']),
              style: TextStyle(color: label, fontSize: 11.5),
            ),
          ),
        if (m['reply'] != null && m['unsent'] != true) _quote(m, own, maxW),
        Padding(
          padding: EdgeInsets.only(
            top: 2,
            bottom: reactions.isNotEmpty ? 16 : 0,
          ),
          child: Row(
            mainAxisAlignment: own
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!own) ...[
                SizedBox(
                  width: 28,
                  child: lastOfRun
                      ? MAvatar(
                          name: '${m['sender'] ?? ''}',
                          photo: m['photo'],
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: GestureDetector(
                  onLongPress: () => _messageMenu(m),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: own
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m['forwarded'] == true && m['unsent'] != true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shortcut_rounded,
                                    size: 12,
                                    color: label,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Forwarded',
                                    style: TextStyle(
                                      color: label,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: flashed
                                  ? [
                                      BoxShadow(
                                        color: _theme.accent.withOpacity(0.55),
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: _bubble(m, own, firstOfRun, lastOfRun),
                          ),
                        ],
                      ),
                      if (m['pinned'] == true)
                        Positioned(
                          top: -6,
                          left: own ? -6 : null,
                          right: own ? null : -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.push_pin,
                              size: 10,
                              color: _theme.accent,
                            ),
                          ),
                        ),
                      if (reactions.isNotEmpty)
                        Positioned(
                          bottom: -16,
                          right: own ? 4 : null,
                          left: own ? null : 4,
                          child: GestureDetector(
                            onTap: () => _messageMenu(m),
                            child: Container(
                              height: 22,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x38000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...reactions
                                      .take(3)
                                      .map(
                                        (r) => Text(
                                          '${r['emoji']}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                  if (total > 1) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '$total',
                                      style: const TextStyle(
                                        color: MC.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (seen != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 3, 2, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _group || !own
                  ? seen
                        .take(6)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: MAvatar(
                              name: '${p['name']}',
                              photo: p['photo'],
                              size: 14,
                            ),
                          ),
                        )
                        .toList()
                  : [
                      Text(
                        'Seen',
                        style: TextStyle(color: label, fontSize: 11),
                      ),
                    ],
            ),
          ),
      ],
    );
  }

  Widget _quote(Map m, bool own, double maxW) {
    final r = m['reply'];
    final dark = _bg.dark;
    Widget content;
    if (r['unsent'] == true) {
      content = const Text(
        'Message unsent',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    } else if ((r['type'] == 'image' || r['type'] == 'gif') &&
        r['image'] != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mPhoto(r['image'])!,
          width: 90,
          height: 70,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } else {
      content = Text(
        r['type'] == 'image'
            ? 'Photo'
            : r['type'] == 'gif'
            ? 'GIF'
            : r['type'] == 'file'
            ? '📎 ${r['file_name'] ?? 'File'}'
            : r['type'] == 'sticker'
            ? 'Sticker'
            : '${r['body'] ?? ''}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: own ? 0 : 34, top: 8),
      child: Column(
        crossAxisAlignment: own
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 12,
                  color: dark ? Colors.white70 : MC.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  _replyLabel(m),
                  style: TextStyle(
                    color: dark ? Colors.white70 : MC.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 8),
            child: Opacity(
              opacity: 0.9,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxW),
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 16),
                decoration: BoxDecoration(
                  color: MC.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: MC.muted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m, bool own, bool first, bool last) {
    final type = '${m['type'] ?? 'text'}';
    const r = Radius.circular(18);
    const s = Radius.circular(4);
    final radius = own
        ? BorderRadius.only(
            topLeft: r,
            bottomLeft: r,
            topRight: first ? r : s,
            bottomRight: last ? r : s,
          )
        : BorderRadius.only(
            topRight: r,
            bottomRight: r,
            topLeft: first ? r : s,
            bottomLeft: last ? r : s,
          );

    if (m['unsent'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MC.line),
        ),
        child: Text(
          own
              ? 'You unsent a message'
              : '${mFirst(m['sender'])} unsent a message',
          style: const TextStyle(
            color: MC.muted,
            fontStyle: FontStyle.italic,
            fontSize: 13.5,
          ),
        ),
      );
    }
    if ((type == 'image' && m['image'] != null) ||
        (type == 'gif' && '${m['body'] ?? ''}'.startsWith('http'))) {
      final url = type == 'image' ? mPhoto(m['image'])! : '${m['body']}';
      return GestureDetector(
        onTap: () => _viewImage(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: MC.line),
              borderRadius: BorderRadius.circular(14),
            ),
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 260),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                width: 160,
                height: 120,
                color: MC.soft,
                child: const Icon(Icons.broken_image_outlined, color: MC.faint),
              ),
            ),
          ),
        ),
      );
    }
    if (type == 'sticker') {
      final key = '${m['body'] ?? ''}';
      final parts = key.split(':');
      final val = parts.length > 1 ? parts.sublist(1).join(':') : key;
      if (parts.first == 'emo')
        return Text(val, style: const TextStyle(fontSize: 64));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Text(
          val.replaceAll('-', ' ').replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFC2410C),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      );
    }
    if (type == 'file') {
      final name = '${m['file_name'] ?? 'File'}';
      return GestureDetector(
        onTap: () => _messageMenu(m),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: own ? _theme.gradient : null,
            color: own ? null : MC.theirs,
            borderRadius: radius,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MFileBadge(name: name, size: 38),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: own ? Colors.white : MC.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${mSize(m['file_size'])}${m['file'] != null ? ' · Download' : ''}',
                          style: TextStyle(
                            color: own ? Colors.white70 : MC.muted,
                            fontSize: 12,
                          ),
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
    if (_isBigEmoji(m)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          '${m['body']}',
          style: const TextStyle(fontSize: 34, height: 1.15),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: own ? _theme.gradient : null,
        color: own ? null : MC.theirs,
        borderRadius: radius,
      ),
      child: Text(
        '${m['body'] ?? ''}',
        style: TextStyle(
          color: own ? Colors.white : MC.ink,
          fontSize: 15,
          height: 1.34,
        ),
      ),
    );
  }

  Widget _replyBar() {
    final r = _replyTo!;
    final meId = _members.firstWhere(
      (x) => x['me'] == true,
      orElse: () => null,
    )?['id'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: MC.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${r['sender_id'] == meId ? 'yourself' : '${r['sender'] ?? ''}'}',
                  style: const TextStyle(
                    color: MC.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  r['type'] == 'image'
                      ? 'Photo'
                      : r['type'] == 'file'
                      ? '📎 ${r['file_name']}'
                      : r['type'] == 'sticker'
                      ? 'Sticker'
                      : r['type'] == 'gif'
                      ? 'GIF'
                      : '${r['body'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MC.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: MC.muted, size: 20),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final accent = _theme.accent;
    final hasText = _text.text.trim().isNotEmpty;
    final typingMode = hasText && !_showTools;
    final like = '${_conv?['emoji'] ?? ''}'.isNotEmpty
        ? '${_conv!['emoji']}'
        : '👍';

    Widget tool(IconData icon, VoidCallback onTap) => IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, color: accent, size: 23),
      onPressed: _sending ? null : onTap,
    );

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 6, 8),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (typingMode)
              tool(
                Icons.add_circle_rounded,
                () => setState(() => _showTools = true),
              )
            else ...[
              tool(Icons.image_rounded, _pickPhotos),
              tool(Icons.photo_camera_rounded, _takePhoto),
              tool(Icons.attach_file_rounded, _pickFiles),
              tool(Icons.gif_box_rounded, _gifSheet),
              tool(
                Icons.emoji_emotions_rounded,
                () => _sheet(
                  (ctx) => _emojiGrid(
                    ctx,
                    (e) => _send(sticker: 'emo:$e'),
                    big: true,
                  ),
                ),
              ),
            ],
            // the box, with the emoji button inside on the right
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: MC.soft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 5000,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => _typing(),
                        style: const TextStyle(
                          color: MC.ink,
                          fontSize: 15,
                          height: 1.35,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Aa',
                          hintStyle: TextStyle(color: MC.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(14, 9, 4, 9),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        color: accent,
                        size: 22,
                      ),
                      onPressed: () =>
                          _sheet((ctx) => _emojiGrid(ctx, _insertEmoji)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
            if (_sending)
              Padding(
                padding: const EdgeInsets.all(9),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: accent,
                  ),
                ),
              )
            else if (hasText)
              IconButton(
                icon: Icon(Icons.send_rounded, color: accent, size: 24),
                onPressed: () => _send(),
              )
            else
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _send(body: like),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(like, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ================= forward: pick a chat or a person ================= */
class _ForwardSheet extends StatefulWidget {
  final Map message;
  const _ForwardSheet({required this.message});

  @override
  State<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<_ForwardSheet> {
  List<dynamic>? _convs;
  List<dynamic> _people = [];
  String _q = '';
  final Set<String> _sent = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    MessengerApi.get('conversations')
        .then((d) {
          if (mounted) setState(() => _convs = d is List ? d : []);
        })
        .catchError((_) {
          if (mounted) setState(() => _convs = []);
        });
    MessengerApi.get('people')
        .then((d) {
          if (mounted) setState(() => _people = d is List ? d : []);
        })
        .catchError((_) {});
  }

  Future<void> _go(String key, Map<String, dynamic> body) async {
    setState(() => _busy.add(key));
    try {
      await MessengerApi.post('messages/${widget.message['id']}/forward', body);
      if (mounted) setState(() => _sent.add(key));
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _busy.remove(key));
  }

  Widget _sendBtn(String key, Map<String, dynamic> body) {
    final sent = _sent.contains(key);
    return SizedBox(
      height: 32,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: sent ? MC.soft : MC.blue,
          foregroundColor: sent ? MC.muted : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: sent || _busy.contains(key) ? null : () => _go(key, body),
        child: Text(
          sent
              ? 'Sent'
              : _busy.contains(key)
              ? '…'
              : 'Send',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final preview = m['type'] == 'image'
        ? '📷 Photo'
        : m['type'] == 'file'
        ? '📎 ${m['file_name']}'
        : m['type'] == 'sticker'
        ? 'Sticker'
        : m['type'] == 'gif'
        ? 'GIF'
        : '${m['body'] ?? ''}';
    final term = _q.trim().toLowerCase();
    final convs = (_convs ?? [])
        .where(
          (c) => term.isEmpty || '${c['name']}'.toLowerCase().contains(term),
        )
        .toList();
    final direct = (_convs ?? [])
        .where((c) => c['is_group'] != true)
        .map((c) => c['other']?['id'])
        .toSet();
    final people = _people
        .where(
          (p) =>
              !direct.contains(p['id']) &&
              (term.isEmpty || '${p['name']}'.toLowerCase().contains(term)),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Forward',
                      style: TextStyle(
                        color: MC.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MC.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: MC.line),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MC.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MC.ink, fontSize: 13.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: MSearch(
                hint: 'Search chats and people',
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: _convs == null
                  ? const Center(
                      child: CircularProgressIndicator(color: MC.blue),
                    )
                  : ListView(
                      children: [
                        if (convs.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
                            child: Text(
                              'Chats',
                              style: TextStyle(
                                color: MC.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ...convs.map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                MConvAvatar(c: c, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${c['name']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: MC.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                _sendBtn('c${c['id']}', {
                                  'conversation_id': c['id'],
                                }),
                              ],
                            ),
                          ),
                        ),
                        if (people.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                            child: Text(
                              'People',
                              style: TextStyle(
                                color: MC.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ...people.map(
                          (p) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                MAvatar(
                                  name: '${p['name']}',
                                  photo: p['photo'],
                                  size: 40,
                                  online: p['online'] == true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${p['name']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: MC.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                _sendBtn('p${p['id']}', {
                                  'employee_id': p['id'],
                                }),
                              ],
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
}

/* ================= GIFs: GIPHY + the shared library (like the web GifPicker) ================= */
class _GifSheet extends StatefulWidget {
  final Color accent;
  final void Function(String url) onPick;
  const _GifSheet({required this.accent, required this.onPick});

  @override
  State<_GifSheet> createState() => _GifSheetState();
}

class _GifSheetState extends State<_GifSheet> {
  String _tab = 'giphy';
  String _q = '';
  Timer? _t;
  bool _loading = true;
  bool _giphyReady = true;
  String? _error;
  List<dynamic> _items = [];
  bool _more = false;
  int _next = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      if (!more) _error = null;
    });
    try {
      if (_tab == 'giphy') {
        final d = await MessengerApi.get('giphy', {
          'q': _q.trim(),
          'offset': '${more ? _next : 0}',
        });
        if (!mounted) return;
        if (d['ready'] == false) {
          setState(() {
            _giphyReady = false;
            _tab = 'library';
          });
          return _load();
        }
        setState(() {
          final items = (d['items'] as List?) ?? [];
          _items = more ? [..._items, ...items] : items;
          _more = d['more'] == true;
          _next = (d['next'] ?? 0) as int;
          _error = d['error'] as String?;
        });
      } else {
        final d = await MessengerApi.get('gifs', {'q': _q.trim()});
        if (!mounted) return;
        setState(() {
          _items = d is List ? d : [];
          _more = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  void _search(String v) {
    _q = v;
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 400), () => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
              child: Row(
                children: [
                  if (_giphyReady) _tabBtn('giphy', 'GIPHY'),
                  _tabBtn('library', 'Library'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MC.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: MSearch(
                hint: _tab == 'giphy' ? 'Search GIPHY' : 'Search GIFs',
                onChanged: _search,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: MC.red, fontSize: 12.5),
                ),
              ),
            Expanded(
              child: _loading && _items.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: widget.accent),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No GIFs found.',
                        style: TextStyle(color: MC.muted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: _items.length + (_more ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _items.length) {
                          if (!_loading)
                            Future.microtask(() => _load(more: true));
                          return Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.accent,
                              ),
                            ),
                          );
                        }
                        final g = _items[i];
                        final url = '${g['url']}';
                        return GestureDetector(
                          onTap: () => widget.onPick(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              color: MC.soft,
                              child: Image.network(
                                '${g['thumb'] ?? url}',
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.gif_box_outlined,
                                  color: MC.faint,
                                ),
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
    );
  }

  Widget _tabBtn(String key, String label) {
    final on = _tab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: on
            ? null
            : () {
                setState(() {
                  _tab = key;
                  _items = [];
                });
                _load();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? MC.blue.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? MC.blue : MC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
