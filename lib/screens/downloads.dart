import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/downloads.dart';
import '../widgets.dart';
import 'player.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _addLink(BuildContext context) async {
    final app = context.read<AppState>();
    final dl = context.read<Downloads>();
    final url = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'direct_link')),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: url,
            autofocus: true,
            decoration: InputDecoration(hintText: tr(context, 'link_hint')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
          FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(ctx, 'play'),
              icon: const Icon(Icons.play_arrow),
              label: Text(tr(context, 'play'))),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'download'),
              icon: const Icon(Icons.download),
              label: Text(tr(context, 'download'))),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final link = url.text.trim();
    final uri = Uri.tryParse(link);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      toast(context, tr(context, 'invalid_link'));
      return;
    }
    final name = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? uri.host;
    final title = Uri.decodeComponent(name).replaceAll(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '');
    if (action == 'play') {
      openPlayer(context, source: link, title: title);
    } else {
      await dl.add(url: link, title: title, dir: app.downloadDir);
      if (context.mounted) toast(context, tr(context, 'download_started'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<Downloads>();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'downloads'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLink(context),
        icon: const Icon(Icons.add_link),
        label: Text(tr(context, 'add_link')),
      ),
      body: dl.tasks.isEmpty
          ? EmptyState(icon: Icons.download_outlined, text: tr(context, 'empty'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 90, top: 8),
              itemCount: dl.tasks.length,
              itemBuilder: (context, i) => _TaskTile(dl.tasks[i]),
            ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final DownloadTask t;
  const _TaskTile(this.t);

  @override
  Widget build(BuildContext context) {
    final dl = context.read<Downloads>();
    final theme = Theme.of(context);
    final statusKey = 'st_${t.status.name}';
    final details = [
      tr(context, statusKey),
      if (t.status != DlStatus.done)
        '${formatBytes(t.received)}${t.total > 0 ? ' / ${formatBytes(t.total)}' : ''}'
      else
        formatBytes(t.total),
      if (t.status == DlStatus.running && t.speed > 0) '${formatBytes(t.speed.round())}/s',
      if (t.status == DlStatus.failed && t.error != null) t.error!,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: Screen.pad(context), vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (t.status != DlStatus.done)
                    LinearProgressIndicator(
                      value: t.status == DlStatus.running ? t.progress : (t.progress ?? 0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  const SizedBox(height: 6),
                  Text(details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: t.status == DlStatus.failed
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (t.status == DlStatus.running || t.status == DlStatus.queued)
              IconButton(
                  tooltip: tr(context, 'pause'), icon: const Icon(Icons.pause), onPressed: () => dl.pause(t)),
            if (t.status == DlStatus.paused || t.status == DlStatus.failed)
              IconButton(
                  tooltip: tr(context, 'resume'),
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => dl.resume(t)),
            if (t.status == DlStatus.done)
              IconButton(
                tooltip: tr(context, 'play'),
                icon: const Icon(Icons.play_circle_fill),
                onPressed: () {
                  if (!File(t.path).existsSync()) {
                    toast(context, tr(context, 'file_missing'));
                    return;
                  }
                  openPlayer(context, source: t.path, title: t.title);
                },
              ),
            PopupMenuButton<String>(
              onSelected: (v) => dl.remove(t, deleteFile: v == 'delete'),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'remove', child: Text(tr(context, 'remove'))),
                if (t.status == DlStatus.done)
                  PopupMenuItem(value: 'delete', child: Text(tr(context, 'delete_file'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
