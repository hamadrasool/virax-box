String _str(dynamic v) {
  if (v == null) return '';
  if (v is List) return v.map((e) => e.toString()).join(', ');
  return v.toString();
}

class Movie {
  final String id;
  final String title;
  final String year;
  final String language;
  final String description;
  final int downloads;

  const Movie({
    required this.id,
    required this.title,
    this.year = '',
    this.language = '',
    this.description = '',
    this.downloads = 0,
  });

  String get thumb => 'https://archive.org/services/img/$id';

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: _str(j['identifier'] ?? j['id']),
        title: _str(j['title']).isEmpty ? _str(j['identifier'] ?? j['id']) : _str(j['title']),
        year: _str(j['year']),
        language: _str(j['language']),
        description: stripHtml(_str(j['description'])),
        downloads: int.tryParse(_str(j['downloads'])) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'language': language,
        'description': description,
        'downloads': downloads,
      };
}

String stripHtml(String s) => s
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .trim();

class MovieFile {
  final String name;
  final String format;
  final int size;
  final String url;
  const MovieFile({required this.name, required this.format, required this.size, required this.url});
}

class SubtitleFile {
  final String name;
  final String url;
  const SubtitleFile(this.name, this.url);
}

class MovieDetail {
  final Movie movie;
  final List<MovieFile> videos;
  final List<SubtitleFile> subtitles;
  const MovieDetail(this.movie, this.videos, this.subtitles);
}

class LocalItem {
  final String path;
  final String title;
  const LocalItem(this.path, this.title);
  factory LocalItem.fromJson(Map<String, dynamic> j) => LocalItem(j['path'], j['title']);
  Map<String, dynamic> toJson() => {'path': path, 'title': title};
}

class HistoryItem {
  final String key; // url or path
  final String title;
  final String? movieId;
  int positionMs;
  HistoryItem({required this.key, required this.title, this.movieId, this.positionMs = 0});
  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
      key: j['key'], title: j['title'], movieId: j['movieId'], positionMs: j['pos'] ?? 0);
  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'movieId': movieId, 'pos': positionMs};
}

class Playlist {
  final String name;
  final String source; // http(s) url or local file path
  const Playlist(this.name, this.source);
  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(j['name'], j['source']);
  Map<String, dynamic> toJson() => {'name': name, 'source': source};
}

class Channel {
  final String name;
  final String url;
  final String group;
  final String logo;
  const Channel({required this.name, required this.url, this.group = '', this.logo = ''});
}

String formatBytes(int b) {
  if (b <= 0) return '—';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = b.toDouble();
  int i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i < 2 ? 0 : 1)} ${u[i]}';
}

const videoExtensions = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'm4v', 'ogv', 'wmv', 'flv', 'ts', 'mpg', 'mpeg', '3gp'];

bool isVideoPath(String p) {
  final i = p.lastIndexOf('.');
  if (i < 0) return false;
  return videoExtensions.contains(p.substring(i + 1).toLowerCase());
}
