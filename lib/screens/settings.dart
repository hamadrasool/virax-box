import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'settings'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(tr(context, 'language')),
                trailing: DropdownButton<String>(
                  value: app.lang,
                  underline: const SizedBox(),
                  items: [
                    for (final e in appLanguages.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => app.setLang(v!),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(tr(context, 'theme')),
                trailing: DropdownButton<ThemeMode>(
                  value: app.themeMode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: ThemeMode.dark, child: Text(tr(context, 'theme_dark'))),
                    DropdownMenuItem(value: ThemeMode.light, child: Text(tr(context, 'theme_light'))),
                    DropdownMenuItem(value: ThemeMode.system, child: Text(tr(context, 'theme_system'))),
                  ],
                  onChanged: (v) => app.setTheme(v!),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(tr(context, 'download_folder')),
                subtitle: Text(app.downloadDir),
                trailing: TextButton(
                  onPressed: () async {
                    final dir = await FilePicker.getDirectoryPath();
                    if (dir != null) app.setDownloadDir(dir);
                  },
                  child: Text(tr(context, 'change')),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(tr(context, 'clear_history')),
                onTap: app.clearHistory,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('${tr(context, 'about')} · Virax Box 1.0'),
                subtitle: Text(tr(context, 'about_text')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
