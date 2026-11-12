import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'screens/discover.dart' show DiscoverScreen, openBrowse;
import 'screens/downloads.dart';
import 'screens/library.dart';
import 'screens/live_tv.dart';
import 'screens/settings.dart';
import 'state/app_state.dart';
import 'state/downloads.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final app = AppState();
  final downloads = Downloads();
  await app.load();
  await downloads.load();
  // Finished downloads show up in the library automatically.
  downloads.onCompleted = (path) => app.addLocalFiles([path]);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: downloads),
    ],
    child: const ViraxBoxApp(),
  ));
}

class ViraxBoxApp extends StatelessWidget {
  const ViraxBoxApp({super.key});

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE50914),
      brightness: b,
      primary: const Color(0xFFE50914),
      onPrimary: Colors.white,
      surface: dark ? const Color(0xFF0F0F12) : null,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B0B0E) : null,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0B0B0E) : null,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'Virax Box',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: app.themeMode,
      builder: (context, child) => Directionality(
        textDirection: app.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: const HomeShell(),
    );
  }
}

/// Side rail on laptops / tablets, bottom bar on phones.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DiscoverScreen(),
    LiveTvScreen(),
    LibraryScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final active = context.select<Downloads, int>(
        (d) => d.tasks.where((t) => t.status == DlStatus.running || t.status == DlStatus.queued).length);
    Widget dlIcon(IconData icon) =>
        active > 0 ? Badge(label: Text('$active'), child: Icon(icon)) : Icon(icon);

    final items = <(Widget, Widget, String)>[
      (const Icon(Icons.home_outlined), const Icon(Icons.home), tr(context, 'discover')),
      (const Icon(Icons.live_tv_outlined), const Icon(Icons.live_tv), tr(context, 'live_tv')),
      (const Icon(Icons.video_library_outlined), const Icon(Icons.video_library), tr(context, 'library')),
      (dlIcon(Icons.download_outlined), dlIcon(Icons.download), tr(context, 'downloads')),
      (const Icon(Icons.settings_outlined), const Icon(Icons.settings), tr(context, 'settings')),
    ];
    final body = IndexedStack(index: _index, children: _pages);

    if (Screen.wide(context)) {
      // Netflix-style top navigation bar on laptops / tablets.
      final bg = Theme.of(context).scaffoldBackgroundColor;
      return Scaffold(
        body: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg, bg.withValues(alpha: 0.9)],
                ),
              ),
              child: Row(
                children: [
                  const Text('VIRAX BOX',
                      style: TextStyle(
                          color: Color(0xFFE50914),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(width: 32),
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _index = i),
                        icon: _index == i ? items[i].$2 : items[i].$1,
                        label: Text(items[i].$3),
                        style: TextButton.styleFrom(
                          foregroundColor: _index == i ? Colors.white : Colors.white60,
                          textStyle: TextStyle(
                              fontSize: 15, fontWeight: _index == i ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: TextField(
                      textInputAction: TextInputAction.search,
                      onSubmitted: (q) => openBrowse(context, query: q),
                      decoration: InputDecoration(
                        hintText: tr(context, 'search_hint'),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in items)
            NavigationDestination(icon: icon, selectedIcon: selected, label: label),
        ],
      ),
    );
  }
}
