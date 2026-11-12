import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;

  String lang = 'en';
  ThemeMode themeMode = ThemeMode.dark;
  String downloadDir = '';
  final List<Movie> favorites = [];
  final List<HistoryItem> history = [];
  final List<LocalItem> library = [];
  final List<Playlist> playlists = [];

  bool get rtl => lang == 'ur';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    lang = _prefs.getString('lang') ?? 'en';
    themeMode = ThemeMode.values[_prefs.getInt('theme') ?? ThemeMode.dark.index];
    downloadDir = _prefs.getString('downloadDir') ?? await _defaultDownloadDir();
    favorites.addAll(_list('favorites').map(Movie.fromJson));
    history.addAll(_list('history').map(HistoryItem.fromJson));
    library.addAll(_list('library').map(LocalItem.fromJson));
    playlists.addAll(_list('playlists').map(Playlist.fromJson));
  }

  static Future<String> _defaultDownloadDir() async {
    Directory? base;
    try {
      base = Platform.isAndroid ? await getExternalStorageDirectory() : await getDownloadsDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    return p.join(base.path, 'Virax Box');
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  void _save(String key, Iterable<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items.toList()));

  void setLang(String v) {
    lang = v;
    _prefs.setString('lang', v);
    notifyListeners();
  }

  void setTheme(ThemeMode v) {
    themeMode = v;
    _prefs.setInt('theme', v.index);
    notifyListeners();
  }

  void setDownloadDir(String v) {
    downloadDir = v;
    _prefs.setString('downloadDir', v);
    notifyListeners();
  }

  // Favorites
  bool isFavorite(String id) => favorites.any((m) => m.id == id);

  void toggleFavorite(Movie m) {
    if (isFavorite(m.id)) {
      favorites.removeWhere((e) => e.id == m.id);
    } else {
      favorites.insert(0, m);
    }
    _save('favorites', favorites.map((e) => e.toJson()));
    notifyListeners();
  }

  // History
  int positionFor(String key) =>
      history.where((h) => h.key == key).map((h) => h.positionMs).firstOrNull ?? 0;

  void recordPlayback(String key, String title, int positionMs, {String? movieId}) {
    history.removeWhere((h) => h.key == key);
    history.insert(0, HistoryItem(key: key, title: title, movieId: movieId, positionMs: positionMs));
    if (history.length > 200) history.removeRange(200, history.length);
    _save('history', history.map((e) => e.toJson()));
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _save('history', const []);
    notifyListeners();
  }

  // Local library
  int addLocalFiles(Iterable<String> paths) {
    var added = 0;
    for (final path in paths) {
      if (library.any((l) => l.path == path)) continue;
      library.insert(0, LocalItem(path, p.basenameWithoutExtension(path)));
      added++;
    }
    if (added > 0) {
      _save('library', library.map((e) => e.toJson()));
      notifyListeners();
    }
    return added;
  }

  Future<int> importFolder(String dir) async {
    final found = <String>[];
    try {
      await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
        if (e is File && isVideoPath(e.path)) found.add(e.path);
      }
    } catch (_) {}
    return addLocalFiles(found);
  }

  Future<void> removeLocal(LocalItem item, {bool deleteFile = false}) async {
    library.removeWhere((l) => l.path == item.path);
    _save('library', library.map((e) => e.toJson()));
    notifyListeners();
    if (deleteFile) {
      try {
        await File(item.path).delete();
      } catch (_) {}
    }
  }

  // Playlists
  void addPlaylist(Playlist pl) {
    playlists.add(pl);
    _save('playlists', playlists.map((e) => e.toJson()));
    notifyListeners();
  }

  void removePlaylist(Playlist pl) {
    playlists.removeWhere((e) => e.source == pl.source && e.name == pl.name);
    _save('playlists', playlists.map((e) => e.toJson()));
    notifyListeners();
  }
}
