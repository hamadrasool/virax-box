import 'package:flutter/material.dart';

import 'l10n.dart';
import 'models.dart';
import 'screens/detail.dart';

/// Layout helpers so the same screens work on phones and large laptops.
class Screen {
  static bool wide(BuildContext c) => MediaQuery.sizeOf(c).width >= 800;
  static double posterWidth(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w < 500) return 112;
    if (w < 1100) return 140;
    return 164;
  }

  static double pad(BuildContext c) => wide(c) ? 28 : 14;
}

class Poster extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const Poster(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(color: bg, child: const Center(child: Icon(Icons.movie_outlined))),
      loadingBuilder: (_, child, progress) => progress == null ? child : ColoredBox(color: bg),
    );
  }
}

class MovieCard extends StatefulWidget {
  final Movie movie;
  final double? width;
  const MovieCard(this.movie, {super.key, this.width});

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final theme = Theme.of(context);
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedScale(
          scale: _hover ? 1.05 : 1,
          duration: const Duration(milliseconds: 140),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => openDetail(context, m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _hover ? const [BoxShadow(blurRadius: 18, color: Colors.black87)] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.expand(child: Poster(m.thumb)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                Text(
                  [m.year, m.language].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openDetail(BuildContext context, Movie m) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(movie: m)));

/// Horizontal, lazily loaded row of posters with a title.
class MovieRow extends StatefulWidget {
  final String title;
  final Future<List<Movie>> Function() loader;
  final VoidCallback? onShowAll;
  const MovieRow({super.key, required this.title, required this.loader, this.onShowAll});

  @override
  State<MovieRow> createState() => _MovieRowState();
}

class _MovieRowState extends State<MovieRow> {
  late Future<List<Movie>> _future = widget.loader();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pw = Screen.posterWidth(context);
    final pad = Screen.pad(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(pad, 18, pad, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (widget.onShowAll != null)
                TextButton(onPressed: widget.onShowAll, child: Text(tr(context, 'show_all'))),
            ],
          ),
        ),
        SizedBox(
          height: pw * 1.4 + 46,
          child: FutureBuilder<List<Movie>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _future = widget.loader()),
                    icon: const Icon(Icons.refresh),
                    label: Text(tr(context, 'retry')),
                  ),
                );
              }
              final items = snap.data;
              if (items != null && items.isEmpty) {
                return Center(child: Text(tr(context, 'no_results')));
              }
              return Scrollbar(
                controller: _scroll,
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 10),
                  itemCount: items?.length ?? 8,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => items == null
                      ? Container(
                          width: pw,
                          margin: const EdgeInsets.only(bottom: 40),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )
                      : MovieCard(items[i], width: pw),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
