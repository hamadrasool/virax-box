import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/archive_api.dart';
import '../state/app_state.dart';
import '../state/downloads.dart';
import '../widgets.dart';
import 'player.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;
  const DetailScreen({super.key, required this.movie});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<MovieDetail> _future = ArchiveApi.detail(widget.movie);

  void _play(MovieDetail d, MovieFile f) => openPlayer(context,
      source: f.url, title: d.movie.title, movieId: d.movie.id, subtitles: d.subtitles);

  Future<void> _download(MovieDetail d, MovieFile f) async {
    final app = context.read<AppState>();
    await context.read<Downloads>().add(url: f.url, title: d.movie.title, dir: app.downloadDir);
    if (mounted) toast(context, tr(context, 'download_started'));
  }

  void _chooseFile(MovieDetail d, void Function(MovieFile) onPick) {
    if (d.videos.length == 1) return onPick(d.videos.first);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(tr(context, 'choose_quality'), style: Theme.of(context).textTheme.titleMedium)),
            for (final f in d.videos)
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${f.format} · ${formatBytes(f.size)}'),
                onTap: () {
                  Navigator.pop(ctx);
                  onPick(f);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final wide = Screen.wide(context);
    final pad = Screen.pad(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: tr(context, 'favorite'),
            icon: Icon(app.isFavorite(widget.movie.id) ? Icons.favorite : Icons.favorite_border),
            color: app.isFavorite(widget.movie.id) ? theme.colorScheme.primary : null,
            onPressed: () => app.toggleFavorite(widget.movie),
          ),
        ],
      ),
      body: FutureBuilder<MovieDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off,
              text: tr(context, 'error'),
              action: FilledButton(
                  onPressed: () => setState(() => _future = ArchiveApi.detail(widget.movie)),
                  child: Text(tr(context, 'retry'))),
            );
          }
          final d = snap.data;
          final m = d?.movie ?? widget.movie;
          final poster = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(aspectRatio: 0.72, child: Poster(m.thumb)),
          );
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (m.year.isNotEmpty) Chip(label: Text('${tr(context, 'year')}: ${m.year}')),
                if (m.language.isNotEmpty)
                  Chip(avatar: const Icon(Icons.translate, size: 16), label: Text(m.language)),
                if (m.downloads > 0)
                  Chip(avatar: const Icon(Icons.visibility, size: 16), label: Text('${m.downloads}')),
                if (d != null && d.subtitles.isNotEmpty)
                  Chip(
                      avatar: const Icon(Icons.subtitles, size: 16),
                      label: Text('${tr(context, 'subtitles')}: ${d.subtitles.length}')),
              ]),
              const SizedBox(height: 16),
              if (d == null)
                const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
              else if (d.videos.isEmpty)
                Text(tr(context, 'no_video'))
              else
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: () => _chooseFile(d, (f) => _play(d, f)),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(tr(context, 'play')),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _chooseFile(d, (f) => _download(d, f)),
                    icon: const Icon(Icons.download),
                    label: Text(
                        '${tr(context, 'download')}${d.videos.length == 1 ? ' · ${formatBytes(d.videos.first.size)}' : ''}'),
                  ),
                ]),
              const SizedBox(height: 20),
              if (m.description.isNotEmpty) ...[
                Text(tr(context, 'overview'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelectableText(m.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            ],
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: EdgeInsets.all(pad),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 260, child: poster),
                        const SizedBox(width: 28),
                        Expanded(child: info),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Center(child: SizedBox(width: 180, child: poster)),
                        const SizedBox(height: 16),
                        info,
                      ]),
              ),
              MovieRow(
                title: tr(context, 'more_to_watch'),
                loader: () async => (await ArchiveApi.search(sort: 'week desc', rows: 24, page: 2))
                    .where((e) => e.id != widget.movie.id)
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
