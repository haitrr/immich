import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TimelineBucketCacheRepository {
  static const _fileName = 'timeline_buckets.json';

  final Future<Directory> Function() _directory;
  final Logger _log = Logger('TimelineBucketCacheRepository');
  Future<void> _pendingWrite = Future.value();
  String? _storedKey;
  List<TimeBucket>? _storedBuckets;

  TimelineBucketCacheRepository({this._directory = getApplicationSupportDirectory});

  Future<File> _file() async => File(p.join((await _directory()).path, _fileName));

  Future<List<TimeBucket>?> read(String key) async {
    await _pendingWrite;
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return null;
      }

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['key'] != key) {
        return null;
      }

      final buckets = [
        for (final entry in json['buckets'] as List<dynamic>)
          TimeBucket(date: DateTime.parse(entry[0] as String), assetCount: entry[1] as int),
      ];
      _storedKey = key;
      _storedBuckets = buckets;
      return buckets;
    } catch (error, stackTrace) {
      _log.warning('Failed to read cached timeline buckets', error, stackTrace);
      return null;
    }
  }

  Future<void> write(String key, List<TimeBucket> buckets) {
    if (key == _storedKey && const ListEquality<TimeBucket>().equals(buckets, _storedBuckets)) {
      return _pendingWrite;
    }

    _storedKey = key;
    _storedBuckets = buckets;
    return _pendingWrite = _pendingWrite.then((_) => _write(key, buckets));
  }

  Future<void> _write(String key, List<TimeBucket> buckets) async {
    try {
      final file = await _file();
      final tempFile = File('${file.path}.tmp');
      final json = jsonEncode({
        'key': key,
        'buckets': [
          for (final bucket in buckets) [bucket.date.toIso8601String(), bucket.assetCount],
        ],
      });
      await tempFile.writeAsString(json, flush: true);
      await tempFile.rename(file.path);
    } catch (error, stackTrace) {
      _log.warning('Failed to write cached timeline buckets', error, stackTrace);
    }
  }
}
