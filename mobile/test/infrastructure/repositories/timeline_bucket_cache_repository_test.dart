import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline_bucket_cache.repository.dart';

void main() {
  late Directory directory;
  late TimelineBucketCacheRepository sut;

  final buckets = [
    TimeBucket(date: DateTime(2026, 11, 20), assetCount: 3),
    TimeBucket(date: DateTime.utc(2026, 11, 19), assetCount: 12),
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('timeline_bucket_cache');
    sut = TimelineBucketCacheRepository(directory: () async => directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('returns null when nothing is cached', () async {
    expect(await sut.read('day:user-1'), isNull);
  });

  test('reads back the buckets written for the same key', () async {
    await sut.write('day:user-1', buckets);

    final restored = await TimelineBucketCacheRepository(directory: () async => directory).read('day:user-1');

    expect(restored, buckets);
    expect(restored!.map((bucket) => bucket.date.isUtc), [false, true]);
  });

  test('ignores buckets cached for another key', () async {
    await sut.write('day:user-1', buckets);

    expect(await sut.read('day:user-2'), isNull);
  });

  test('returns null for an unreadable cache file', () async {
    await File('${directory.path}/timeline_buckets.json').writeAsString('not json');

    expect(await sut.read('day:user-1'), isNull);
  });

  test('keeps the latest of consecutive writes', () async {
    final newer = [TimeBucket(date: DateTime(2026, 11, 21), assetCount: 1), ...buckets];

    await Future.wait([sut.write('day:user-1', buckets), sut.write('day:user-1', newer)]);

    expect(await TimelineBucketCacheRepository(directory: () async => directory).read('day:user-1'), newer);
  });
}
