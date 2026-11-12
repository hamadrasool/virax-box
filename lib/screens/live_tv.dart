import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/m3u.dart';
import '../state/app_state.dart';
import '../widgets.dart';
import 'player.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> with AutomaticKeepAliveClientMixin {
  Playlist? _current;
  Future<List<Channel>>? _channels;
  String _group = '';
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  void _open(Playlist pl) => setState(() {
        _current = pl;
        _group = '';
        _query = '';
        _channels = M3u.load(pl.source);
      });

  Future<void> _addDialog() async {
    final app = context.read<AppState>();
    final name = TextEditingController();
    final url = TextEditingController();
    final pl = await showDialog<Playlist>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'add_playlist')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: tr(context, 'playlist_name'))),
            TextField(
                controller: url,
                decoration: InputDecoration(labelText: tr(context, 'playlist_url'), hintText: 'https://…/list.m3u')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(tr(context, 'pick_m3u_file')),
              onPressed: () async {
                final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['m3u', 'm3u8', 'txt']);
                if (f?.path != null && ctx.mounted) {
                  Navigator.pop(ctx, Playlist(name.text.trim().isEmpty ? f!.name : name.text.trim(), f!.path!));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
          FilledButton(
            onPressed: () {
              final u = url.text.trim();
              if (!u.startsWith('http://') && !u.startsWith('https://')) return;
              Navigator.pop(ctx, Playlist(name.text.trim().isEmpty ? Uri.parse(u).host : name.text.trim(), u));
            },
            child: Text(tr(context, 'ok')),
          ),
        ],
      ),
    );
    if (pl != null) {
      app.addPlaylist(pl);
      _open(pl);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    final pad = Screen.pad(context);
    if (_current != null && !app.playlists.contains(_current)) {
      _current = null;
      _channels = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'live_tv')),
        actions: [
          IconButton(tooltip: tr(context, 'add_playlist'), icon: const Icon(Icons.playlist_add), onPressed: _addDialog),
        ],
      ),
      body: app.playlists.isEmpty
          ? EmptyState(
              icon: Icons.live_tv,
              text: tr(context, 'empty_tv'),
              action: FilledButton.icon(
                  onPressed: _addDialog, icon: const Icon(Icons.add), label: Text(tr(context, 'add_playlist'))),
            )
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 6),
                  child: Row(children: [
                    for (final pl in app.playlists)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: InputChip(
                          label: Text(pl.name),
                          selected: identical(pl, _current),
                          onPressed: () => _open(pl),
                          onDeleted: () => app.removePlaylist(pl),
                          deleteButtonTooltipMessage: tr(context, 'delete_playlist'),
                        ),
                      ),
                  ]),
                ),
                Expanded(
                  child: _channels == null
                      ? EmptyState(icon: Icons.touch_app_outlined, text: tr(context, 'empty_tv'))
                      : FutureBuilder<List<Channel>>(
                          future: _channels,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return EmptyState(
                                icon: Icons.wifi_off,
                                text: tr(context, 'error'),
                                action: FilledButton(
                                    onPressed: () => _open(_current!), child: Text(tr(context, 'retry'))),
                              );
                            }
                            return _channelList(snap.data!, pad);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _channelList(List<Channel> all, double pad) {
    final groups = all.map((c) => c.group).where((g) => g.isNotEmpty).toSet().toList()..sort();
    final q = _query.toLowerCase();
    final list = all
        .where((c) => (_group.isEmpty || c.group == _group) && (q.isEmpty || c.name.toLowerCase().contains(q)))
        .toList();
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: tr(context, 'search_channels'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (groups.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              children: [
                for (final g in ['', ...groups])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(g.isEmpty ? tr(context, 'all') : g),
                      selected: _group == g,
                      onSelected: (_) => setState(() => _group = g),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: Icons.search_off, text: tr(context, 'no_results'))
              : GridView.builder(
                  padding: EdgeInsets.all(pad),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 64,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: c.logo.isEmpty ? const Icon(Icons.tv) : Poster(c.logo, fit: BoxFit.contain),
                        ),
                        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: c.group.isEmpty ? null : Text(c.group, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => openPlayer(context, source: c.url, title: c.name, live: true),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
