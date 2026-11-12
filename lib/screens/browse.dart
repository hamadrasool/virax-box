import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/archive_api.dart';
import '../widgets.dart';

/// Full grid with search, category, language and sort filters + endless scroll.
class BrowseScreen extends StatefulWidget {
  final String query;
  final String category;
  final String sort;
  final String? language;
  const BrowseScreen({super.key, this.query = '', this.category = 'cat_all', this.sort = 'sort_popular', this.language});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final _search = TextEditingController(text: widget.query);
  late String _category = widget.category;
  late String _sort = widget.sort;
  late String? _language = widget.language;
  final _scroll = ScrollController();
  final List<Movie> _items = [];
  int _page = 0;
  bool _loading = false, _end = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _end = false;
      _loading = false;
      _error = null;
    });
    _more();
  }

  Future<void> _more() async {
    if (_loading || _end) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ArchiveApi.search(
        query: _search.text,
        collection: ArchiveApi.categories[_category]!,
        sort: ArchiveApi.sorts[_sort]!,
        language: _language,
        page: _page + 1,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _page++;
        _items.addAll(res);
        _end = res.length < 40;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = Screen.pad(context);
    final pw = Screen.posterWidth(context);
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 42,
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reset(),
            decoration: InputDecoration(
              hintText: tr(context, 'search_hint'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 6),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox(),
                  items: [
                    for (final s in ArchiveApi.sorts.keys) DropdownMenuItem(value: s, child: Text(tr(context, s))),
                  ],
                  onChanged: (v) {
                    _sort = v!;
                    _reset();
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _language ?? '',
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: '', child: Text(tr(context, 'all_languages'))),
                    for (final l in ArchiveApi.languages.keys) DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: (v) {
                    _language = v == '' ? null : v;
                    _reset();
                  },
                ),
                const SizedBox(width: 12),
                for (final c in ArchiveApi.categories.keys)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(tr(context, c)),
                      selected: _category == c,
                      onSelected: (_) {
                        _category = c;
                        _reset();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty && !_loading
                ? EmptyState(
                    icon: _error != null ? Icons.wifi_off : Icons.search_off,
                    text: tr(context, _error != null ? 'error' : 'no_results'),
                    action: _error != null
                        ? FilledButton(onPressed: _more, child: Text(tr(context, 'retry')))
                        : null,
                  )
                : GridView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.all(pad),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: pw + 20,
                      mainAxisExtent: pw * 1.4 + 50,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _items.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) => i >= _items.length
                        ? const Center(child: CircularProgressIndicator())
                        : MovieCard(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
