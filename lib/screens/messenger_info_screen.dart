import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/messenger_api.dart';
import '../widgets/messenger_ui.dart';

/// Chat info – same sections as the web (Messenger.jsx → ChatInfo):
/// Pin · Add · Search, Chat info, Customize chat (group name, theme, background, quick reaction),
/// Chat members (message / make admin / remove, add people), Pinned messages, Media / files / links, Leave group
class MessengerInfoScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final List<dynamic> members;
  final List<dynamic> pinned;
  final void Function(Map<String, dynamic> payload)
  onPayload; // show() payload from the server → the chat updates
  final void Function(int messageId) onJump;
  final VoidCallback onSearch;
  final void Function(int conversationId, String name) onOpenChat;
  final void Function(int messageId) onUnpinMessage;

  const MessengerInfoScreen({
    super.key,
    required this.conversation,
    required this.members,
    required this.pinned,
    required this.onPayload,
    required this.onJump,
    required this.onSearch,
    required this.onOpenChat,
    required this.onUnpinMessage,
  });

  @override
  State<MessengerInfoScreen> createState() => _MessengerInfoScreenState();
}

class _MessengerInfoScreenState extends State<MessengerInfoScreen> {
  late Map<String, dynamic> _conv = Map<String, dynamic>.from(
    widget.conversation,
  );
  late List<dynamic> _members = List.from(widget.members);
  late List<dynamic> _pinned = List.from(widget.pinned);
  late final _name = TextEditingController(
    text: widget.conversation['has_name'] == true
        ? '${widget.conversation['name']}'
        : '',
  );
  bool _chatPinned = false;
  bool _busy = false;
  final _open = <String>{'members', 'shared', 'pinned'};
  String _kind = 'media';
  final Map<String, List<dynamic>> _shared = {};
  final Map<String, bool> _sharedMore = {};
  final Map<String, int?> _sharedNext = {};

  int get _cid => _conv['id'] as int;
  bool get _group => _conv['is_group'] == true;
  Map? get _me => _members.cast<Map?>().firstWhere(
    (m) => m?['me'] == true,
    orElse: () => null,
  );
  bool get _iAmAdmin => _me?['is_admin'] == true;
  Color get _accent => mThemeOf(_conv['theme']).accent;

  @override
  void initState() {
    super.initState();
    _loadPinnedChat();
    _loadShared('media');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadPinnedChat() async {
    try {
      final list = await MessengerApi.get('conversations');
      final c = (list as List).cast<Map?>().firstWhere(
        (x) => x?['id'] == _cid,
        orElse: () => null,
      );
      if (mounted) setState(() => _chatPinned = c?['pinned'] == true);
    } catch (_) {}
  }

  Future<void> _loadShared(String kind, {bool more = false}) async {
    try {
      final q = <String, String>{'kind': kind};
      if (more && _sharedNext[kind] != null)
        q['before_id'] = '${_sharedNext[kind]}';
      final d = await MessengerApi.get('conversations/$_cid/shared', q);
      if (!mounted) return;
      setState(() {
        final items = (d['items'] as List?) ?? [];
        _shared[kind] = more ? [...(_shared[kind] ?? []), ...items] : items;
        _sharedMore[kind] = d['has_more'] == true;
        _sharedNext[kind] = d['next_before'] as int?;
      });
    } catch (_) {
      if (mounted) setState(() => _shared[kind] = _shared[kind] ?? []);
    }
  }

  // every change returns the chat (show() payload) → keep the panel and the chat in sync
  void _apply(dynamic d) {
    if (d is! Map) return;
    final p = Map<String, dynamic>.from(d);
    setState(() {
      if (p['conversation'] != null)
        _conv = Map<String, dynamic>.from(p['conversation']);
      if (p['members'] != null) _members = List.from(p['members']);
      if (p['pinned'] != null) _pinned = List.from(p['pinned']);
    });
    widget.onPayload(p);
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _customize(Map<String, dynamic> body) => _run(
    () async => _apply(
      await MessengerApi.post('conversations/$_cid/customize', body, 'PUT'),
    ),
  );

  Future<void> _rename() => _run(() async {
    _apply(
      await MessengerApi.post('conversations/$_cid', {
        'name': _name.text.trim(),
      }, 'PUT'),
    );
    if (mounted) mSnack(context, 'Group name saved');
  });

  Future<void> _admin(Map p, bool on) => _run(
    () async => _apply(
      await MessengerApi.post('conversations/$_cid/members/${p['id']}/admin', {
        'is_admin': on,
      }, 'PUT'),
    ),
  );

  Future<void> _remove(Map p) => _run(() async {
    final r = await MessengerApi.post(
      'conversations/$_cid/members/${p['id']}',
      null,
      'DELETE',
    );
    if (r is Map && r['left'] == true) {
      if (!mounted) return;
      mSnack(context, 'You left the group');
      Navigator.of(context)
        ..pop()
        ..pop();
      return;
    }
    _apply(r);
  });

  Future<void> _togglePinChat() => _run(() async {
    final on = !_chatPinned;
    await MessengerApi.post('conversations/$_cid/pin', {'pinned': on});
    if (mounted) setState(() => _chatPinned = on);
  });

  Future<void> _message(Map p) => _run(() async {
    final d = await MessengerApi.post('direct', {'employee_id': p['id']});
    final c = d['conversation'];
    if (!mounted) return;
    Navigator.pop(context);
    widget.onOpenChat(c['id'] as int, '${c['name']}');
  });

  // ── Add people ───────────────────────────────────────────────
  Future<void> _addPeople() async {
    List<dynamic> people = [];
    try {
      people = (await MessengerApi.get('people')) as List;
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
      return;
    }
    if (!mounted) return;
    final already = _members.map((m) => m['id']).toSet();
    final picked = <Map>[];
    String q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final term = q.trim().toLowerCase();
          final list = people
              .where(
                (p) =>
                    !already.contains(p['id']) &&
                    (term.isEmpty ||
                        '${p['name']}'.toLowerCase().contains(term) ||
                        '${p['role'] ?? ''}'.toLowerCase().contains(term)),
              )
              .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add people',
                            style: TextStyle(
                              color: MC.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: MC.muted,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: MC.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: MSearch(
                      hint: 'Search employees',
                      onChanged: (v) => setS(() => q = v),
                    ),
                  ),
                  if (picked.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: picked
                              .map(
                                (p) => InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setS(
                                    () => picked.removeWhere(
                                      (x) => x['id'] == p['id'],
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MC.blue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '${mFirst(p['name'])}  ×',
                                      style: const TextStyle(
                                        color: MC.blue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final on = picked.any((x) => x['id'] == p['id']);
                        return InkWell(
                          onTap: () => setS(() {
                            if (on) {
                              picked.removeWhere((x) => x['id'] == p['id']);
                            } else {
                              picked.add(p);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
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
                                    style: const TextStyle(
                                      color: MC.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: on ? MC.blue : Colors.transparent,
                                    border: Border.all(
                                      color: on ? MC.blue : MC.muted,
                                      width: 2,
                                    ),
                                  ),
                                  child: on
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MC.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: MC.soft,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: picked.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _run(
                                    () async => _apply(
                                      await MessengerApi.post(
                                        'conversations/$_cid/members',
                                        {
                                          'employee_ids': picked
                                              .map((p) => p['id'])
                                              .toList(),
                                        },
                                      ),
                                    ),
                                  );
                                },
                          child: Text(
                            picked.isEmpty
                                ? 'Add people'
                                : 'Add ${picked.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _emojiSheet() {
    const emoji = [
      '👍',
      '❤️',
      '😆',
      '😮',
      '😢',
      '😠',
      '🔥',
      '🎉',
      '👏',
      '🙏',
      '💯',
      '✅',
      '😂',
      '🥰',
      '😎',
      '🤝',
      '💪',
      '👌',
      '⭐',
      '🍀',
      '☕',
      '🍕',
      '🚀',
      '🌸',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 8,
          padding: const EdgeInsets.all(12),
          children: emoji
              .map(
                (e) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(ctx);
                    _customize({'emoji': e});
                  },
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _memberMenu(Map p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: MC.ink,
              ),
              title: const Text(
                'Message',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _message(p);
              },
            ),
            if (_iAmAdmin) ...[
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: MC.ink,
                ),
                title: Text(
                  p['is_admin'] == true ? 'Remove as admin' : 'Make admin',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _admin(p, p['is_admin'] != true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: MC.red),
                title: const Text(
                  'Remove from group',
                  style: TextStyle(color: MC.red, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove(p);
                },
              ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
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
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    mSnack(context, msg);
  }

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final admins = _members
        .where((m) => m['is_admin'] == true)
        .map((m) => mFirst(m['name']))
        .join(', ');
    final other = _conv['other'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: MC.ink,
        elevation: 0,
        title: const Text(
          'Chat info',
          style: TextStyle(
            color: MC.ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: _busy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, color: _accent),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // intro
          Center(
            child: GestureDetector(
              onTap: !_group && other?['photo'] != null
                  ? () => _viewImage(mPhoto(other['photo'])!)
                  : null,
              child: MConvAvatar(
                c: _conv,
                size: 80,
                online: _group ? null : other?['online'] == true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '${_conv['name']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MC.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              _group ? '${_members.length} members' : mActive(other),
              style: const TextStyle(color: MC.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),

          // Pin · Add · Search
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quick(
                Icons.push_pin_outlined,
                _chatPinned ? 'Unpin' : 'Pin',
                _togglePinChat,
                on: _chatPinned,
              ),
              if (_group)
                _quick(Icons.person_add_alt_1_outlined, 'Add', _addPeople),
              _quick(Icons.search_rounded, 'Search', () {
                Navigator.pop(context);
                widget.onSearch();
              }),
            ],
          ),
          const SizedBox(height: 10),

          if (_group)
            _section('info', 'Chat info', [
              _kv('Admins', admins.isEmpty ? '—' : admins),
              _kv('Members', '${_members.length}'),
            ]),

          _section('customize', 'Customize chat', [
            if (_group) ...[
              _label('Group name'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: MC.ink, fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Name this group',
                        hintStyle: const TextStyle(color: MC.muted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: MC.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _btn(
                    'Save',
                    _busy ||
                            _name.text.trim() ==
                                (_conv['has_name'] == true
                                    ? '${_conv['name']}'
                                    : '')
                        ? null
                        : _rename,
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            _label('Theme'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.95,
              children: mThemes.entries.map((t) {
                final on = '${_conv['theme'] ?? 'default'}' == t.key;
                return _tile(
                  on: on,
                  onTap: _busy || on
                      ? null
                      : () => _customize({'theme': t.key}),
                  swatch: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: t.value.gradient,
                    ),
                  ),
                  label: _cap(t.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _label('Background'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.95,
              children: mBackgrounds.entries.map((b) {
                final on = '${_conv['background'] ?? 'none'}' == b.key;
                return _tile(
                  on: on,
                  onTap: _busy || on
                      ? null
                      : () => _customize({'background': b.key}),
                  swatch: Container(
                    width: 40,
                    height: 34,
                    decoration: b.value.deco.copyWith(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MC.line),
                    ),
                    child: b.key == 'none'
                        ? const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: MC.muted,
                          )
                        : null,
                  ),
                  label: _cap(b.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quick reaction',
                    style: TextStyle(
                      color: MC.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Material(
                  color: MC.soft,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _busy ? null : _emojiSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_conv['emoji'] ?? ''}'.isEmpty
                                ? '👍'
                                : '${_conv['emoji']}',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Change',
                            style: TextStyle(
                              color: MC.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          if (_group)
            _section('members', 'Chat members (${_members.length})', [
              ..._members.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: p['photo'] != null
                            ? () => _viewImage(mPhoto(p['photo'])!)
                            : null,
                        child: MAvatar(
                          name: '${p['name']}',
                          photo: p['photo'],
                          size: 40,
                          online: p['online'] == true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['name']}${p['me'] == true ? ' (You)' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MC.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [
                                if (p['is_admin'] == true) 'Admin',
                                if (mActive(p).isNotEmpty) mActive(p),
                              ].join(' · '),
                              style: const TextStyle(
                                color: MC.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p['me'] != true)
                        Material(
                          color: MC.soft,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _busy ? null : () => _memberMenu(p),
                            child: const SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: MC.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _btn('+  Add people', _busy ? null : _addPeople),
              ),
            ]),

          if (_pinned.isNotEmpty)
            _section('pinned', 'Pinned messages (${_pinned.length})', [
              ..._pinned.map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onJump(p['id'] as int);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                if ((p['type'] == 'image' ||
                                        p['type'] == 'gif') &&
                                    p['image'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      mPhoto(p['image'])!,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                                  )
                                else if (p['type'] == 'file')
                                  MFileBadge(
                                    name: '${p['text'] ?? ''}',
                                    size: 36,
                                  )
                                else
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 16,
                                      color: _accent,
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p['sender'] ?? ''}',
                                        style: const TextStyle(
                                          color: MC.ink,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${p['text'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: MC.ink,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (p['pinned_by'] != null)
                                        Text(
                                          'Pinned by ${mFirst(p['pinned_by'])} · ${mAgo(p['pinned_at'])}',
                                          style: const TextStyle(
                                            color: MC.muted,
                                            fontSize: 11.5,
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
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: MC.muted,
                        ),
                        onPressed: () {
                          widget.onUnpinMessage(p['id'] as int);
                          setState(
                            () =>
                                _pinned.removeWhere((x) => x['id'] == p['id']),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ]),

          _section('shared', 'Media, files and links', [_sharedTabs()]),

          if (_group)
            _section('privacy', 'Privacy & support', [
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: MC.soft,
                    foregroundColor: MC.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _busy || _me == null
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.white,
                              title: const Text('Leave group?'),
                              content: const Text(
                                "You won't get messages from this group anymore.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text(
                                    'Leave',
                                    style: TextStyle(color: MC.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) _remove(_me!);
                        },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Leave group',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  String _cap(String k) =>
      k == 'igb' ? 'IGB' : k[0].toUpperCase() + k.substring(1);

  Widget _quick(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool on = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : onTap,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? _accent.withOpacity(0.14) : MC.soft,
              ),
              child: Icon(icon, size: 20, color: on ? _accent : MC.ink),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: MC.ink, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _section(String key, String title, List<Widget> children) {
    final open = _open.contains(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              setState(() => open ? _open.remove(key) : _open.add(key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: MC.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: MC.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
      ],
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        color: MC.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(k, style: const TextStyle(color: MC.muted, fontSize: 13.5)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: MC.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _btn(String label, VoidCallback? onTap) => TextButton(
    style: TextButton.styleFrom(
      backgroundColor: MC.soft,
      foregroundColor: MC.ink,
      disabledForegroundColor: MC.faint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _tile({
    required bool on,
    required VoidCallback? onTap,
    required Widget swatch,
    required String label,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? _accent : Colors.transparent,
            width: 2,
          ),
          color: on ? _accent.withOpacity(0.06) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            swatch,
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: MC.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sharedTabs() {
    final items = _shared[_kind];
    Widget body;
    if (items == null) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
        ),
      );
    } else if (items.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            _kind == 'media'
                ? 'No photos yet.'
                : _kind == 'files'
                ? 'No files yet.'
                : 'No links yet.',
            style: const TextStyle(color: MC.muted, fontSize: 13),
          ),
        ),
      );
    } else if (_kind == 'media') {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          children: items.where((m) => m['url'] != null).map((m) {
            final url = m['gif'] == true ? '${m['url']}' : mPhoto(m['url'])!;
            return GestureDetector(
              onTap: () => _viewImage(url),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(color: MC.soft),
              ),
            );
          }).toList(),
        ),
      );
    } else if (_kind == 'files') {
      body = Column(
        children: items
            .map(
              (f) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: f['url'] == null
                    ? null
                    : () => _copy(
                        '${f['url']}',
                        'Download link copied – paste it in your browser',
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      MFileBadge(name: '${f['name'] ?? ''}', size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f['name'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MC.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${mSize(f['size'])} · ${mFirst(f['sender'])} · ${mAgo(f['time'])}',
                              style: const TextStyle(
                                color: MC.muted,
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
            )
            .toList(),
      );
    } else {
      body = Column(
        children: items
            .map(
              (l) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _copy('${l['url']}', 'Link copied'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MC.soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: MC.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l['host'] ?? ''}',
                              style: const TextStyle(
                                color: MC.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${l['url']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MC.muted,
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
            )
            .toList(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: MC.soft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children:
                [
                  ['media', 'Media'],
                  ['files', 'Files'],
                  ['links', 'Links'],
                ].map((t) {
                  final on = _kind == t[0];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _kind = t[0]);
                        if (_shared[t[0]] == null) _loadShared(t[0]);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: on
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          t[1],
                          style: TextStyle(
                            color: on ? MC.ink : MC.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        body,
        if (_sharedMore[_kind] == true)
          TextButton(
            onPressed: () => _loadShared(_kind, more: true),
            child: Text('Show more', style: TextStyle(color: _accent)),
          ),
      ],
    );
  }
}
