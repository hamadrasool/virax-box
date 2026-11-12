import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/archive_api.dart';
import '../state/app_state.dart';
import '../widgets.dart';

Future<void> openPlayer(
  BuildContext context, {
  required String source,
  required String title,
  String? movieId,
  List<SubtitleFile> subtitles = const [],
  bool live = false,
}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          PlayerScreen(source: source, title: title, movieId: movieId, subtitles: subtitles, live: live),
    ));

/// Resolves the best video file of an Internet Archive item and plays it.
Future<void> playMovie(BuildContext context, Movie m) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final d = await ArchiveApi.detail(m);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (d.videos.isEmpty) {
      toast(context, tr(context, 'no_video'));
      return;
    }
    await openPlayer(context,
        source: d.videos.first.url, title: d.movie.title, movieId: m.id, subtitles: d.subtitles);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    toast(context, tr(context, 'error'));
  }
}

class PlayerScreen extends StatefulWidget {
  final String source;
  final String title;
  final String? movieId;
  final List<SubtitleFile> subtitles;
  final bool live;
  const PlayerScreen({
    super.key,
    required this.source,
    required this.title,
    this.movieId,
    this.subtitles = const [],
    this.live = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  late final AppState _app = context.read<AppState>();
  final _subs = <StreamSubscription>[];
  Duration _position = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.stream.position.listen((p) => _position = p));
    _subs.add(_player.stream.error.listen((e) {
      if (mounted) setState(() => _error = e);
    }));
    final start = widget.live ? 0 : _app.positionFor(widget.source);
    _player.open(Media(widget.source, start: start > 5000 ? Duration(milliseconds: start) : null));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (!widget.live) {
      final dur = _player.state.duration;
      final finished = dur > Duration.zero && _position.inMilliseconds > dur.inMilliseconds * 0.95;
      final pos = finished ? 0 : _position.inMilliseconds;
      final app = _app;
      final src = widget.source, title = widget.title, id = widget.movieId;
      // Defer so listeners are not notified while the tree is being torn down.
      Future.microtask(() => app.recordPlayback(src, title, pos, movieId: id));
    }
    _player.dispose();
    super.dispose();
  }

  String _trackLabel(String id, String? title, String? language) =>
      [title, language].where((e) => e != null && e.isNotEmpty).join(' · ').ifEmpty('Track $id');

  void _pickSubtitle() {
    final tracks = _player.state.tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.subtitles_off_outlined),
              title: Text(tr(context, 'off')),
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(tr(context, 'auto')),
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.auto());
                Navigator.pop(ctx);
              },
            ),
            for (final t in tracks)
              ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(_trackLabel(t.id, t.title, t.language)),
                onTap: () {
                  _player.setSubtitleTrack(t);
                  Navigator.pop(ctx);
                },
              ),
            for (final s in widget.subtitles)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(s.name),
                onTap: () {
                  _player.setSubtitleTrack(SubtitleTrack.uri(s.url, title: s.name));
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(tr(context, 'load_sub_file')),
              onTap: () async {
                Navigator.pop(ctx);
                final f = await FilePicker.pickFile(
                    type: FileType.custom, allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub']);
                if (f?.path != null) {
                  _player.setSubtitleTrack(SubtitleTrack.uri(f!.path!, title: f.name));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickAudio() {
    final tracks = _player.state.tracks.audio.where((t) => t.id != 'no').toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in tracks)
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: Text(t.id == 'auto' ? tr(context, 'auto') : _trackLabel(t.id, t.title, t.language)),
                onTap: () {
                  _player.setAudioTrack(t);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              tooltip: tr(context, 'subtitles'), icon: const Icon(Icons.subtitles), onPressed: _pickSubtitle),
          IconButton(
              tooltip: tr(context, 'audio'), icon: const Icon(Icons.audiotrack), onPressed: _pickAudio),
          if (!widget.live)
            PopupMenuButton<double>(
              tooltip: tr(context, 'speed'),
              icon: const Icon(Icons.speed),
              onSelected: _player.setRate,
              itemBuilder: (_) => [
                for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(value: r, child: Text('${r}x')),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(child: Video(controller: _controller)),
          if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
