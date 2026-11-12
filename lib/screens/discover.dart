import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/archive_api.dart';
import '../state/app_state.dart';
import '../widgets.dart';
import 'browse.dart';
import 'player.dart';

const netflixRed = Color(0xFFE50914);

void openBrowse(BuildContext context,
    {String query = '', String category = 'cat_all', String sort = 'sort_popular', String? language}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BrowseScreen(query: query, category: category, sort: sort, language: language),
  ));
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with AutomaticKeepAliveClientMixin {
  String? _language;
  final _search = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppState>();
    final pad = Screen.pad(context);
    final wide = Screen.wide(context);
    final resumable = app.history.where((h) => h.positionMs > 5000).take(12).toList();

    Widget row(String titleKey, {String category = 'cat_all', required String sort}) => MovieRow(
          key: ValueKey('$titleKey-$category-$sort-$_language'),
          title: tr(context, titleKey),
          loader: () => ArchiveApi.search(
            collection: ArchiveApi.categories[category]!,
            sort: ArchiveApi.sorts[sort]!,
            language: _language,
            rows: 24,
          ),
          onShowAll: () => openBrowse(context, category: category, sort: sort, language: _language),
        );

    return CustomScrollView(
      slivers: [
        // Hero shows the most recently added films first.
        SliverToBoxAdapter(child: _Hero(key: ValueKey('hero-$_language'), language: _language)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 6, pad, 0),
            child: Row(
              children: [
                if (!wide)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (q) => openBrowse(context, query: q, language: _language),
                        decoration: InputDecoration(
                          hintText: tr(context, 'search_hint'),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 10),
                PopupMenuButton<String?>(
                  tooltip: tr(context, 'all_languages'),
                  onSelected: (v) => setState(() => _language = v == '' ? null : v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: '', child: Text(tr(context, 'all_languages'))),
                    for (final l in ArchiveApi.languages.keys) PopupMenuItem(value: l, child: Text(l)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.translate, size: 18),
                    label: Text(_language ?? tr(context, 'all_languages')),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (resumable.isNotEmpty) SliverToBoxAdapter(child: _ContinueRow(items: resumable)),
        SliverList.list(children: [
          row('sort_latest', sort: 'sort_latest'),
          row('sort_trending', sort: 'sort_trending'),
          Top10Row(key: ValueKey('top10-$_language'), language: _language),
          row('sort_popular', sort: 'sort_popular'),
          for (final c in ArchiveApi.categories.keys.skip(1)) row(c, category: c, sort: 'sort_trending'),
          const SizedBox(height: 40),
        ]),
      ],
    );
  }
}

/// Full-bleed Netflix-style banner of the newest additions.
class _Hero extends StatefulWidget {
  final String? language;
  const _Hero({super.key, this.language});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _page = PageController();
  List<Movie> _items = [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ArchiveApi.search(
          sort: ArchiveApi.sorts['sort_latest']!, language: widget.language, rows: 8);
      if (!mounted) return;
      setState(() => _items = items);
      _timer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (!_page.hasClients || _items.length < 2) return;
        _page.animateToPage((_index + 1) % _items.length,
            duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = Screen.wide(context);
    final height = wide ? (size.height * 0.62).clamp(340.0, 560.0) : 360.0;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final pad = Screen.pad(context) + (wide ? 16 : 0);

    if (_items.isEmpty) {
      return SizedBox(
          height: height,
          child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)));
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final m = _items[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Low-res posters look best blurred and enlarged as ambience.
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Transform.scale(scale: 1.4, child: Poster(m.thumb)),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [bg.withValues(alpha: 0.95), bg.withValues(alpha: 0.55), bg.withValues(alpha: 0.2)],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, bg],
                        stops: const [0, 0.6, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(pad, 24, pad, 44),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Text('V',
                                    style: TextStyle(
                                        color: netflixRed, fontSize: 22, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 6),
                                Text(tr(context, 'sort_latest').toUpperCase(),
                                    style: const TextStyle(
                                        letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 10),
                              Text(m.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: wide ? 44 : 28,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                      shadows: const [Shadow(blurRadius: 12, color: Colors.black54)])),
                              const SizedBox(height: 8),
                              Text([m.year, m.language].where((e) => e.isNotEmpty).join('  •  '),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              if (wide && m.description.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 560),
                                  child: Text(m.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(height: 1.4)),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Row(children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 18, vertical: 14),
                                  ),
                                  onPressed: () => playMovie(context, m),
                                  icon: const Icon(Icons.play_arrow, size: 28),
                                  label: Text(tr(context, 'play'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white24,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 14),
                                  ),
                                  onPressed: () => openDetail(context, m),
                                  icon: const Icon(Icons.info_outline),
                                  label: Text(tr(context, 'more_info'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        if (wide)
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: AspectRatio(
                                aspectRatio: 0.7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black87)],
                                  ),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10), child: Poster(m.thumb)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 22 : 7,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == _index ? netflixRed : Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Netflix-style "Top 10" row with big rank numbers.
class Top10Row extends StatefulWidget {
  final String? language;
  const Top10Row({super.key, this.language});

  @override
  State<Top10Row> createState() => _Top10RowState();
}

class _Top10RowState extends State<Top10Row> {
  late final Future<List<Movie>> _future = ArchiveApi.search(
      sort: ArchiveApi.sorts['sort_trending']!, language: widget.language, rows: 10);

  @override
  Widget build(BuildContext context) {
    final pad = Screen.pad(context);
    final pw = Screen.posterWidth(context);
    final h = pw * 1.4;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(pad, 18, pad, 8),
          child: Text(tr(context, 'top10'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: h + 10,
          child: FutureBuilder<List<Movie>>(
            future: _future,
            builder: (context, snap) {
              final items = snap.data ?? const <Movie>[];
              if (items.isEmpty) return const SizedBox();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => openDetail(context, items[i]),
                  child: SizedBox(
                    width: pw * 1.55,
                    child: Row(
                      children: [
                        Text('${i + 1}',
                            style: TextStyle(
                              fontSize: h * 0.62,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -8,
                              color: theme.scaffoldBackgroundColor,
                              shadows: const [
                                Shadow(color: Colors.white54, blurRadius: 1, offset: Offset(2, 0)),
                                Shadow(color: Colors.white54, blurRadius: 1, offset: Offset(-2, 0)),
                                Shadow(color: Colors.white54, blurRadius: 1, offset: Offset(0, 2)),
                                Shadow(color: Colors.white54, blurRadius: 1, offset: Offset(0, -2)),
                              ],
                            )),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(height: h, child: Poster(items[i].thumb)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueRow extends StatelessWidget {
  final List<HistoryItem> items;
  const _ContinueRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final pad = Screen.pad(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(pad, 18, pad, 8),
          child: Text(tr(context, 'continue_watching'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final h = items[i];
              return SizedBox(
                width: 260,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.play_circle_fill),
                    title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_fmt(h.positionMs)),
                    onTap: () => openPlayer(context, source: h.key, title: h.title, movieId: h.movieId),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}
