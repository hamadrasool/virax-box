import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models.dart';

class M3u {
  static Future<List<Channel>> load(String source) async {
    String text;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final res = await Dio().get<String>(source,
          options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 60)));
      text = res.data ?? '';
    } else {
      text = await File(source).readAsString(encoding: const Utf8Codec(allowMalformed: true));
    }
    return parse(text);
  }

  static List<Channel> parse(String text) {
    final out = <Channel>[];
    final attr = RegExp(r'([\w-]+)="([^"]*)"');
    String? name;
    String group = '', logo = '';
    for (var line in const LineSplitter().convert(text)) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        final attrs = {for (final m in attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!};
        group = attrs['group-title'] ?? '';
        logo = attrs['tvg-logo'] ?? '';
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : (attrs['tvg-name'] ?? '');
        if (name.isEmpty) name = attrs['tvg-name'] ?? 'Channel';
      } else if (line.startsWith('#EXTGRP:')) {
        group = line.substring(8).trim();
      } else if (!line.startsWith('#')) {
        out.add(Channel(name: name ?? line, url: line, group: group, logo: logo));
        name = null;
        group = '';
        logo = '';
      }
    }
    return out;
  }
}
