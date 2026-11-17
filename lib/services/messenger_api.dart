import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Talks to the web Messenger through /api/mobile/messenger/<path>?employeeId=
class MessengerApi {
  static String employeeId = '';

  static bool get isEmployee =>
      employeeId.isNotEmpty && employeeId != '0' && employeeId != 'null';

  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse(
    '${ApiConstants.baseUrl}/messenger/$path',
  ).replace(queryParameters: {'employeeId': employeeId, ...?q});

  static dynamic _decode(http.Response r) {
    dynamic d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {
      throw MessengerError('Server error (${r.statusCode})', r.statusCode);
    }
    if (r.statusCode >= 400) {
      final msg = d is Map
          ? (d['message'] ?? 'Request failed').toString()
          : 'Request failed';
      throw MessengerError(msg, r.statusCode);
    }
    return d;
  }

  static Future<dynamic> get(String path, [Map<String, String>? q]) async {
    final r = await http.get(
      _u(path, q),
      headers: {'Accept': 'application/json'},
    );
    return _decode(r);
  }

  /// POST, or PUT / DELETE through _method (like the web routes)
  static Future<dynamic> post(
    String path, [
    Map<String, dynamic>? body,
    String? method,
  ]) async {
    final r = await http.post(
      _u(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({...?body, if (method != null) '_method': method}),
    );
    return _decode(r);
  }

  static Future<dynamic> send(
    int conversationId, {
    String body = '',
    List<File> images = const [],
    List<PlatformFile> files = const [],
    int? replyToId,
    String? sticker,
    String? gif,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      _u('conversations/$conversationId/messages'),
    );
    req.headers['Accept'] = 'application/json';
    if (body.trim().isNotEmpty) req.fields['body'] = body.trim();
    if (replyToId != null) req.fields['reply_to_id'] = '$replyToId';
    if (sticker != null) req.fields['sticker'] = sticker;
    if (gif != null) req.fields['gif'] = gif;
    for (final f in images) {
      req.files.add(await http.MultipartFile.fromPath('images[]', f.path));
    }
    for (final f in files) {
      if (f.path != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'files[]',
            f.path!,
            filename: f.name,
          ),
        );
      } else if (f.bytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes('files[]', f.bytes!, filename: f.name),
        );
      }
    }
    final r = await http.Response.fromStream(await req.send());
    return _decode(r);
  }
}

class MessengerError implements Exception {
  final String message;
  final int status;
  MessengerError(this.message, this.status);
  @override
  String toString() => message;
}
