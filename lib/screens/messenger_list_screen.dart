import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/messenger_api.dart';
import '../widgets/messenger_ui.dart';
import 'messenger_chat_screen.dart';

/// Chats – same as the web Messenger list (Messenger.jsx → ChatList)
class MessengerListScreen extends StatefulWidget {
  const MessengerListScreen({super.key});

  @override
  State<MessengerListScreen> createState() => _MessengerListScreenState();
}

class _MessengerListScreenState extends State<MessengerListScreen> {
  static const _filters = [
    ['all', 'All'],
    ['unread', 'Unread'],
    ['people', 'People'],
    ['groups', 'Groups'],
  ];

  final _q = TextEditingController();
  List<dynamic>? _convs;
  List<dynamic> _people = [];
  String _filter = 'all';
  String? _error;
  String _sig = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    MessengerApi.employeeId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).employeeId;
    _load();
    _loadPeople();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _q.dispose();
    super.dispose();
  }

  // only redraw when something really changed (no blinking every 5 s)
  String _signature(List list) => list
      .map(
        (c) =>
            '${c['id']}|${c['name']}|${c['preview']}|${c['time']}|${c['unread']}|${c['pinned']}|${c['online']}',
      )
      .join('~');

  Future<void> _load({bool quiet = false}) async {
    try {
      final d = await MessengerApi.get('conversations');
      if (!mounted) return;
      final list = d is List ? d : [];
      final sig = _signature(list);
      if (sig == _sig && _convs != null) return;
      setState(() {
        _sig = sig;
        _convs = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted || quiet) return;
      setState(() {
        _convs ??= [];
        _error = e.toString();
      });
    }
  }

  Future<void> _loadPeople() async {
    try {
      final d = await MessengerApi.get('people');
      if (mounted) setState(() => _people = d is List ? d : []);
    } catch (_) {}
  }

  Future<void> _openChat(int id, String name) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessengerChatScreen(conversationId: id, title: name),
      ),
    );
    _load(quiet: true);
  }

  Future<void> _openDirect(dynamic employeeId, String name) async {
    try {
      final d = await MessengerApi.post('direct', {'employee_id': employeeId});
      final c = d['conversation'];
      if (!mounted) return;
      _openChat(c['id'] as int, '${c['name'] ?? name}');
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _togglePin(Map c) async {
    final on = c['pinned'] != true;
    setState(() => c['pinned'] = on);
    try {
      await MessengerApi.post('conversations/${c['id']}/pin', {'pinned': on});
    } catch (e) {
      if (mounted) mSnack(context, e.toString(), error: true);
    }
    _sig = '';
    _load(quiet: true);
  }

  // ── New message / New group (like PeopleModal) ─────────────────
  void _peopleSheet({required bool group}) {
    final name = TextEditingController();
    final picked = <Map>[];
    String q = '';
    bool busy = false;
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
          final list = _people
              .where(
                (p) =>
                    term.isEmpty ||
                    '${p['name']}'.toLowerCase().contains(term) ||
                    '${p['role'] ?? ''}'.toLowerCase().contains(term),
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
                        Expanded(
                          child: Text(
                            group ? 'New group' : 'New message',
                            style: const TextStyle(
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
                    child: Column(
                      children: [
                        if (group) ...[
                          TextField(
                            controller: name,
                            maxLength: 80,
                            style: const TextStyle(color: MC.ink, fontSize: 14),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Group name (optional)',
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
                                borderSide: const BorderSide(color: MC.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        MSearch(
                          hint: 'Search employees',
                          autofocus: !group,
                          onChanged: (v) => setS(() => q = v),
                        ),
                        if (picked.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Text(
                              'No employees found.',
                              style: TextStyle(color: MC.muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final p = list[i];
                              final on = picked.any((x) => x['id'] == p['id']);
                              return InkWell(
                                onTap: () {
                                  if (!group) {
                                    Navigator.pop(ctx);
                                    _openDirect(p['id'], '${p['name']}');
                                  } else {
                                    setS(() {
                                      if (on) {
                                        picked.removeWhere(
                                          (x) => x['id'] == p['id'],
                                        );
                                      } else {
                                        picked.add(p);
                                      }
                                    });
                                  }
                                },
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${p['name']}',
                                              style: const TextStyle(
                                                color: MC.ink,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if ('${p['role'] ?? ''}'
                                                    .isNotEmpty ||
                                                p['online'] == true)
                                              Text(
                                                '${p['role'] ?? ''}'.isNotEmpty
                                                    ? '${p['role']}'
                                                    : mActive(p),
                                                style: const TextStyle(
                                                  color: MC.muted,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (group)
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: on
                                                ? MC.blue
                                                : Colors.transparent,
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
                  if (group)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                        child: Column(
                          children: [
                            SizedBox(
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
                                onPressed: picked.length < 2 || busy
                                    ? null
                                    : () async {
                                        setS(() => busy = true);
                                        try {
                                          final d = await MessengerApi.post(
                                            'groups',
                                            {
                                              'name': name.text.trim(),
                                              'member_ids': picked
                                                  .map((p) => p['id'])
                                                  .toList(),
                                            },
                                          );
                                          final c = d['conversation'];
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          _sig = '';
                                          _load(quiet: true);
                                          _openChat(
                                            c['id'] as int,
                                            '${c['name']}',
                                          );
                                        } catch (e) {
                                          setS(() => busy = false);
                                          if (mounted)
                                            mSnack(
                                              context,
                                              e.toString(),
                                              error: true,
                                            );
                                        }
                                      },
                                child: Text(
                                  busy ? 'Creating…' : 'Create group',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pick at least 2 people.',
                              style: TextStyle(color: MC.muted, fontSize: 12),
                            ),
                          ],
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

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final term = _q.text.trim().toLowerCase();
    final convs = _convs ?? [];
    final shown = convs
        .where(
          (c) =>
              (term.isEmpty || '${c['name']}'.toLowerCase().contains(term)) &&
              (_filter == 'all' ||
                  (_filter == 'unread' && (c['unread'] ?? 0) > 0) ||
                  (_filter == 'people' && c['is_group'] != true) ||
                  (_filter == 'groups' && c['is_group'] == true)),
        )
        .toList();
    // pinned on top, newest first inside
    final pinned = shown.where((c) => c['pinned'] == true).toList();
    final rest = shown.where((c) => c['pinned'] != true).toList();
    final ordered = [...pinned, ...rest];
    final unreadCount = convs.where((c) => (c['unread'] ?? 0) > 0).length;
    final directIds = convs
        .where((c) => c['is_group'] != true)
        .map((c) => c['other']?['id'])
        .toSet();
    final peopleHits = term.isEmpty
        ? []
        : _people
              .where(
                (p) =>
                    '${p['name']}'.toLowerCase().contains(term) &&
                    !directIds.contains(p['id']),
              )
              .take(8)
              .toList();
    final activeNow = _people.where((p) => p['online'] == true).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: MC.ink,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: MC.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          MCircle(
            icon: Icons.group_add_outlined,
            tip: 'New group',
            onTap: () => _peopleSheet(group: true),
          ),
          const SizedBox(width: 8),
          MCircle(
            icon: Icons.edit_rounded,
            tip: 'New message',
            onTap: () => _peopleSheet(group: false),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _convs == null
          ? const Center(child: CircularProgressIndicator(color: MC.blue))
          : _error != null && convs.isEmpty
          ? _errorView()
          : RefreshIndicator(
              color: MC.blue,
              onRefresh: () async {
                _sig = '';
                await _load();
                await _loadPeople();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: MSearch(
                      controller: _q,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // All · Unread (n) · People · Groups
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: _filters.map((f) {
                        final on = _filter == f[0];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _filter = f[0]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: on
                                    ? MC.blue.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    f[1],
                                    style: TextStyle(
                                      color: on ? MC.blue : MC.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (f[0] == 'unread' && unreadCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                      ),
                                      height: 18,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: MC.red,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Active now (online only, like the web)
                  if (term.isEmpty &&
                      _filter != 'groups' &&
                      activeNow.isNotEmpty)
                    SizedBox(
                      height: 88,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        itemCount: activeNow.length,
                        itemBuilder: (_, i) {
                          final p = activeNow[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _openDirect(p['id'], '${p['name']}'),
                            child: SizedBox(
                              width: 66,
                              child: Column(
                                children: [
                                  MAvatar(
                                    name: '${p['name']}',
                                    photo: p['photo'],
                                    size: 48,
                                    online: true,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mFirst(p['name']),
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
                          );
                        },
                      ),
                    ),
                  if (shown.isEmpty && peopleHits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                      child: Text(
                        term.isNotEmpty
                            ? 'No results.'
                            : _filter == 'unread'
                            ? 'No unread chats. 🎉'
                            : _filter == 'groups'
                            ? 'No group chats yet. Make one with the group button.'
                            : _filter == 'people'
                            ? 'No direct chats yet.'
                            : 'No chats yet. Start one with the pencil button.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: MC.muted, fontSize: 13.5),
                      ),
                    ),
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (_filter == 'all' &&
                        term.isEmpty &&
                        (i == 0 ||
                            (ordered[i - 1]['pinned'] == true) !=
                                (ordered[i]['pinned'] == true)))
                      _sub(ordered[i]['pinned'] == true ? 'Pinned' : 'Recent'),
                    _convTile(ordered[i]),
                  ],
                  if (peopleHits.isNotEmpty) _sub('People'),
                  ...peopleHits.map(
                    (p) => InkWell(
                      onTap: () => _openDirect(p['id'], '${p['name']}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            MAvatar(
                              name: '${p['name']}',
                              photo: p['photo'],
                              size: 44,
                              online: p['online'] == true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p['name']}',
                                    style: const TextStyle(
                                      color: MC.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${p['role'] ?? ''}'.isNotEmpty
                                        ? '${p['role']}'
                                        : mActive(p),
                                    style: const TextStyle(
                                      color: MC.muted,
                                      fontSize: 13,
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
                ],
              ),
            ),
    );
  }

  Widget _sub(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Text(
      t,
      style: const TextStyle(
        color: MC.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _convTile(Map c) {
    final unread = (c['unread'] ?? 0) as int;
    final bold = unread > 0;
    final isGroup = c['is_group'] == true;
    final preview = '${c['preview'] ?? ''}'.isNotEmpty
        ? '${c['preview']}'
        : (isGroup ? '${c['members']} members' : '');
    return InkWell(
      onTap: () => _openChat(c['id'] as int, '${c['name']}'),
      onLongPress: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: Icon(
              Icons.push_pin_outlined,
              color: c['pinned'] == true ? MC.muted : MC.blue,
            ),
            title: Text(
              c['pinned'] == true ? 'Unpin chat' : 'Pin chat',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _togglePin(c);
            },
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            MConvAvatar(c: c, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c['pinned'] == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin, size: 13, color: MC.blue),
                        ),
                      Flexible(
                        child: Text(
                          '${c['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MC.ink,
                            fontSize: 15.5,
                            fontWeight: bold
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: bold ? MC.ink : MC.muted,
                            fontSize: 13.5,
                            fontWeight: bold
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if ('${c['time'] ?? ''}'.isNotEmpty)
                        Text(
                          ' · ${mAgo(c['time'])}',
                          style: TextStyle(
                            color: bold ? MC.ink : MC.muted,
                            fontSize: 13.5,
                            fontWeight: bold
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: MC.blue,
                  shape: BoxShape.circle,
                ),
              ),
            if (isGroup)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: MC.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GROUP',
                  style: TextStyle(
                    color: MC.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: MC.faint),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: MC.ink, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MC.blue,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _convs = null;
                  _error = null;
                });
                _load();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
