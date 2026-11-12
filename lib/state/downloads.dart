import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

enum DlStatus { queued, running, paused, done, failed }

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String path;
  int received;
  int total;
  DlStatus status;
  String? error;
  double speed = 0; // bytes / second
  CancelToken? token;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.path,
    this.received = 0,
    this.total = 0,
    this.status = DlStatus.queued,
    this.error,
  });

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'],
        url: j['url'],
        title: j['title'],
        path: j['path'],
        received: j['received'] ?? 0,
        total: j['total'] ?? 0,
        status: DlStatus.values[j['status'] ?? 0],
        error: j['error'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'path': path,
        'received': received,
        'total': total,
        'status': status.index,
        'error': error,
      };
}

/// Resumable (HTTP Range) download manager with a small concurrency limit.
class Downloads extends ChangeNotifier {
  static const maxConcurrent = 2;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    headers: {'User-Agent': 'ViraxBox/1.0'},
  ));
  final List<DownloadTask> tasks = [];
  late SharedPreferences _prefs;

  /// Called with the final file path when a download completes.
  void Function(String path)? onCompleted;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('downloads');
    if (raw == null) return;
    try {
      for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        final t = DownloadTask.fromJson(j);
        // Anything that was active when the app closed can be resumed by hand.
        if (t.status == DlStatus.running || t.status == DlStatus.queued) t.status = DlStatus.paused;
        tasks.add(t);
      }
    } catch (_) {}
  }

  void _persist() => _prefs.setString('downloads', jsonEncode(tasks.map((t) => t.toJson()).toList()));

  static String safeName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
    return cleaned.isEmpty ? 'video' : (cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned);
  }

  Future<DownloadTask> add({required String url, required String title, required String dir}) async {
    await Directory(dir).create(recursive: true);
    final uri = Uri.parse(url);
    var ext = p.extension(uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
    if (ext.isEmpty || ext.length > 6) ext = '.mp4';
    final base = safeName(title);
    var path = p.join(dir, '$base$ext');
    var n = 1;
    while (File(path).existsSync() || File('$path.part').existsSync() || tasks.any((t) => t.path == path)) {
      path = p.join(dir, '$base (${n++})$ext');
    }
    final task = DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      title: title,
      path: path,
    );
    tasks.insert(0, task);
    _persist();
    notifyListeners();
    _pump();
    return task;
  }

  void pause(DownloadTask t) {
    if (t.status == DlStatus.running) {
      t.token?.cancel('paused');
    } else if (t.status == DlStatus.queued) {
      t.status = DlStatus.paused;
      _persist();
      notifyListeners();
    }
  }

  void resume(DownloadTask t) {
    if (t.status == DlStatus.paused || t.status == DlStatus.failed) {
      t.status = DlStatus.queued;
      t.error = null;
      notifyListeners();
      _pump();
    }
  }

  Future<void> remove(DownloadTask t, {bool deleteFile = false}) async {
    t.token?.cancel('removed');
    tasks.remove(t);
    _persist();
    notifyListeners();
    try {
      final part = File('${t.path}.part');
      if (await part.exists()) await part.delete();
      if (deleteFile && await File(t.path).exists()) await File(t.path).delete();
    } catch (_) {}
  }

  void _pump() {
    var running = tasks.where((t) => t.status == DlStatus.running).length;
    for (final t in tasks.reversed) {
      if (running >= maxConcurrent) break;
      if (t.status == DlStatus.queued) {
        running++;
        _run(t);
      }
    }
  }

  Future<void> _run(DownloadTask t) async {
    t.status = DlStatus.running;
    t.token = CancelToken();
    notifyListeners();
    final part = File('${t.path}.part');
    IOSink? sink;
    try {
      var existing = await part.exists() ? await part.length() : 0;
      final res = await _dio.get<ResponseBody>(
        t.url,
        cancelToken: t.token,
        options: Options(
          responseType: ResponseType.stream,
          headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
          validateStatus: (s) => s != null && (s < 400 || s == 416),
        ),
      );
      if (res.statusCode != 416) {
        if (res.statusCode != 206) existing = 0; // server ignored the range: start over
        final len = int.tryParse(res.headers.value('content-length') ?? '') ?? 0;
        t.total = len > 0 ? existing + len : 0;
        t.received = existing;
        sink = part.openWrite(mode: existing > 0 ? FileMode.append : FileMode.write);
        var lastTick = DateTime.now();
        var lastBytes = t.received;
        await for (final chunk in res.data!.stream) {
          sink.add(chunk);
          t.received += chunk.length;
          final now = DateTime.now();
          final ms = now.difference(lastTick).inMilliseconds;
          if (ms >= 500) {
            t.speed = (t.received - lastBytes) * 1000 / ms;
            lastTick = now;
            lastBytes = t.received;
            notifyListeners();
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
        if (t.total > 0 && t.received < t.total) {
          throw const HttpException('Connection closed before the download finished');
        }
      }
      await part.rename(t.path);
      t.status = DlStatus.done;
      t.total = t.received = await File(t.path).length();
      onCompleted?.call(t.path);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        t.status = DlStatus.paused;
      } else {
        t.status = DlStatus.failed;
        t.error = e.message ?? e.type.name;
      }
    } catch (e) {
      t.status = DlStatus.failed;
      t.error = e.toString();
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      t.speed = 0;
      t.token = null;
      if (tasks.contains(t)) _persist();
      notifyListeners();
      _pump();
    }
  }
}
