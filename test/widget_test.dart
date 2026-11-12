import 'package:flutter_test/flutter_test.dart';
import 'package:virax_box/models.dart';
import 'package:virax_box/services/m3u.dart';
import 'package:virax_box/state/downloads.dart';

void main() {
  test('M3U parser reads names, groups, logos and urls', () {
    final channels = M3u.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="a" tvg-logo="http://x/a.png" group-title="News",Alpha News
http://example.com/a.m3u8
#EXTINF:-1,Beta
#EXTVLCOPT:http-user-agent=x
http://example.com/b.m3u8
''');
    expect(channels.length, 2);
    expect(channels[0].name, 'Alpha News');
    expect(channels[0].group, 'News');
    expect(channels[0].logo, 'http://x/a.png');
    expect(channels[0].url, 'http://example.com/a.m3u8');
    expect(channels[1].name, 'Beta');
    expect(channels[1].group, '');
  });

  test('Movie.fromJson tolerates lists and missing fields', () {
    final m = Movie.fromJson({
      'identifier': 'abc',
      'language': ['English', 'Urdu'],
      'year': 1950,
      'description': '<p>Hello<br/>World &amp; all</p>',
    });
    expect(m.title, 'abc');
    expect(m.language, 'English, Urdu');
    expect(m.year, '1950');
    expect(m.description, 'Hello\nWorld & all');
  });

  test('helpers', () {
    expect(Downloads.safeName('a/b:c?'), 'a_b_c_');
    expect(isVideoPath(r'C:\x\Movie.MKV'), true);
    expect(isVideoPath('notes.txt'), false);
    expect(formatBytes(1536 * 1024), '1.5 MB');
  });
}
