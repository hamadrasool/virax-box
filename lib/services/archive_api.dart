import 'package:dio/dio.dart';

import '../models.dart';

/// Internet Archive client. Only curated, freely-licensed / public-domain
/// movie collections are queried.
class ArchiveApi {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'User-Agent': 'ViraxBox/1.0'},
  ));

  /// key -> archive.org collection id
  static const categories = <String, String>{
    'cat_all': 'feature_films',
    'cat_comedy': 'Comedy_Films',
    'cat_scifi': 'SciFi_Horror',
    'cat_noir': 'Film_Noir',
    'cat_silent': 'silent_films',
    'cat_animation': 'animationandcartoons',
    'cat_short': 'short_films',
    'cat_tv': 'classic_tv',
  };

  /// display name -> archive language terms
  static const languages = <String, List<String>>{
    'English': ['English', 'eng'],
    'Hindi': ['Hindi', 'hin'],
    'Urdu': ['Urdu', 'urd'],
    'Arabic': ['Arabic', 'ara'],
    'Bengali': ['Bengali', 'ben'],
    'Punjabi': ['Punjabi', 'pan'],
    'Tamil': ['Tamil', 'tam'],
    'Spanish': ['Spanish', 'spa'],
    'French': ['French', 'fre', 'fra'],
    'German': ['German', 'ger', 'deu'],
    'Italian': ['Italian', 'ita'],
    'Russian': ['Russian', 'rus'],
    'Japanese': ['Japanese', 'jpn'],
    'Chinese': ['Chinese', 'chi', 'zho'],
    'Korean': ['Korean', 'kor'],
    'Turkish': ['Turkish', 'tur'],
    'Portuguese': ['Portuguese', 'por'],
  };

  static const sorts = <String, String>{
    'sort_latest': 'addeddate desc',
    'sort_trending': 'week desc',
    'sort_popular': 'downloads desc',
    'sort_new': 'addeddate desc',
    'sort_year': 'year desc',
    'sort_title': 'titleSorter asc',
  };

  static Future<List<Movie>> search({
    String query = '',
    String collection = 'feature_films',
    String? language,
    String sort = 'downloads desc',
    int page = 1,
    int rows = 40,
  }) async {
    final parts = <String>['mediatype:movies', 'collection:($collection)'];
    final q = query.trim().replaceAll(RegExp(r'[():"\[\]{}]'), ' ').trim();
    if (q.isNotEmpty) parts.add('($q)');
    if (language != null && languages[language] != null) {
      parts.add('language:(${languages[language]!.join(' OR ')})');
    }
    final res = await _dio.get('https://archive.org/advancedsearch.php', queryParameters: {
      'q': parts.join(' AND '),
      'fl[]': ['identifier', 'title', 'year', 'language', 'downloads', 'description'],
      'sort[]': sort,
      'rows': rows,
      'page': page,
      'output': 'json',
    });
    final docs = (res.data['response']['docs'] as List).cast<Map<String, dynamic>>();
    return docs.map(Movie.fromJson).toList();
  }

  static Future<MovieDetail> detail(Movie base) async {
    final res = await _dio.get('https://archive.org/metadata/${base.id}');
    final data = res.data as Map<String, dynamic>;
    final meta = (data['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final files = (data['files'] as List? ?? []).cast<Map<String, dynamic>>();
    String urlOf(String name) =>
        'https://archive.org/download/${base.id}/${name.split('/').map(Uri.encodeComponent).join('/')}';

    final videos = <MovieFile>[];
    final subs = <SubtitleFile>[];
    for (final f in files) {
      final name = (f['name'] ?? '').toString();
      final lower = name.toLowerCase();
      if (lower.endsWith('.srt') || lower.endsWith('.vtt')) {
        subs.add(SubtitleFile(name, urlOf(name)));
      } else if (isVideoPath(lower)) {
        videos.add(MovieFile(
          name: name,
          format: (f['format'] ?? '').toString(),
          size: int.tryParse((f['size'] ?? '0').toString()) ?? 0,
          url: urlOf(name),
        ));
      }
    }
    // Prefer widely playable formats, biggest (best quality) first.
    int rank(MovieFile f) {
      final n = f.name.toLowerCase();
      if (n.endsWith('.mp4') || n.endsWith('.m4v')) return 0;
      if (n.endsWith('.mkv') || n.endsWith('.webm')) return 1;
      return 2;
    }

    videos.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : b.size.compareTo(a.size);
    });

    final movie = Movie.fromJson({
      ...base.toJson(),
      'identifier': base.id,
      if (meta['title'] != null) 'title': meta['title'],
      if (meta['year'] != null || meta['date'] != null)
        'year': meta['year'] ?? meta['date'].toString().split('-').first,
      if (meta['language'] != null) 'language': meta['language'],
      if (meta['description'] != null) 'description': meta['description'],
    });
    return MovieDetail(movie, videos, subs);
  }
}
