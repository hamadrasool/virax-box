import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../widgets.dart';
import 'player.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _importFiles(BuildContext context) async {
    final app = context.read<AppState>();
    final files = await FilePicker.pickFiles(type: FileType.video);
    app.addLocalFiles(files.map((f) => f.path).whereType<String>());
  }

  Future<void> _importFolder(BuildContext context) async {
    final app = context.read<AppState>();
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) await app.importFolder(dir);
  }

  Future<void> _export(BuildContext context, LocalItem item) async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    try {
      await File(item.path).copy(p.join(dir, p.basename(item.path)));
      if (context.mounted) toast(context, tr(context, 'copied'));
    } catch (e) {
      if (context.mounted) toast(context, '${tr(context, 'error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final importButtons = Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
      FilledButton.icon(
          onPressed: () => _importFiles(context),
          icon: const Icon(Icons.video_file_outlined),
          label: Text(tr(context, 'import_files'))),
      FilledButton.tonalIcon(
          onPressed: () => _importFolder(context),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(tr(context, 'import_folder'))),
    ]);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'library')),
          bottom: TabBar(tabs: [
            Tab(text: tr(context, 'files')),
            Tab(text: tr(context, 'favorites')),
            Tab(text: tr(context, 'history')),
          ]),
        ),
        body: TabBarView(children: [
          // My files
          app.library.isEmpty
              ? EmptyState(
                  icon: Icons.video_library_outlined, text: tr(context, 'empty_library'), action: importButtons)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: importButtons),
                    for (final item in app.library)
                      ListTile(
                        leading: const Icon(Icons.movie_outlined),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          if (!File(item.path).existsSync()) {
                            toast(context, tr(context, 'file_missing'));
                            return;
                          }
                          openPlayer(context, source: item.path, title: item.title);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'export') _export(context, item);
                            if (v == 'remove') app.removeLocal(item);
                            if (v == 'delete') _confirmDelete(context, app, item);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'export', child: Text(tr(context, 'export_copy'))),
                            PopupMenuItem(value: 'remove', child: Text(tr(context, 'remove'))),
                            PopupMenuItem(value: 'delete', child: Text(tr(context, 'delete_file'))),
                          ],
                        ),
                      ),
                  ],
                ),
          // Favorites
          app.favorites.isEmpty
              ? EmptyState(icon: Icons.favorite_border, text: tr(context, 'empty'))
              : GridView.builder(
                  padding: EdgeInsets.all(Screen.pad(context)),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: Screen.posterWidth(context) + 20,
                    mainAxisExtent: Screen.posterWidth(context) * 1.4 + 50,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: app.favorites.length,
                  itemBuilder: (_, i) => MovieCard(app.favorites[i]),
                ),
          // History
          app.history.isEmpty
              ? EmptyState(icon: Icons.history, text: tr(context, 'empty'))
              : ListView(
                  children: [
                    for (final h in app.history)
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(h.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => openPlayer(context, source: h.key, title: h.title, movieId: h.movieId),
                      ),
                  ],
                ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState app, LocalItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, 'delete_file')),
        content: Text(item.path),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, 'cancel'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              app.removeLocal(item, deleteFile: true);
            },
            child: Text(tr(context, 'delete_file')),
          ),
        ],
      ),
    );
  }
}
