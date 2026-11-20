import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline_bucket_cache.repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockTimelineRepository extends Mock implements TimelineRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late Directory directory;
  late _MockTimelineRepository timelineRepository;
  late _MockSettingsRepository settingsRepository;
  late StreamController<List<Bucket>> liveBuckets;
  late TimelineBucketCacheRepository bucketCache;
  late int liveSubscriptions;

  final cachedBuckets = [TimeBucket(date: DateTime(2026, 11, 19), assetCount: 4)];
  final currentBuckets = [
    TimeBucket(date: DateTime(2026, 11, 20), assetCount: 1),
    TimeBucket(date: DateTime(2026, 11, 19), assetCount: 4),
  ];

  setUpAll(() {
    registerFallbackValue(GroupAssetsBy.day);
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('timeline_factory');
    timelineRepository = _MockTimelineRepository();
    settingsRepository = _MockSettingsRepository();
    liveBuckets = StreamController<List<Bucket>>.broadcast();
    bucketCache = TimelineBucketCacheRepository(directory: () async => directory);
    liveSubscriptions = 0;

    when(() => settingsRepository.appConfig).thenReturn(const AppConfig());
    when(() => timelineRepository.main(any(), any())).thenReturn((
      assetSource: (_, _) async => const [],
      bucketSource: () {
        liveSubscriptions++;
        return liveBuckets.stream;
      },
      origin: TimelineOrigin.main,
    ));
  });

  tearDown(() async {
    await liveBuckets.close();
    await directory.delete(recursive: true);
  });

  TimelineFactory createFactory() => TimelineFactory(
    timelineRepository: timelineRepository,
    settingsRepository: settingsRepository,
    bucketCacheRepository: bucketCache,
  );

  Future<void> untilLiveSubscriptions(int count) => Future.doWhile(() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return liveSubscriptions < count;
  }).timeout(const Duration(seconds: 5));

  Future<void> seedCache(List<String> users, List<TimeBucket> buckets) async {
    final service = createFactory().main(users);
    final emitted = service.watchBuckets().first;
    await untilLiveSubscriptions(2);
    liveBuckets.add(buckets);
    await emitted;
    await service.dispose();
    liveSubscriptions = 0;
  }

  test('emits the cached buckets before the database answers', () async {
    await seedCache(['user-1'], cachedBuckets);

    final service = createFactory().main(['user-1']);
    final emissions = StreamQueue(service.watchBuckets());

    expect(await emissions.next, cachedBuckets);

    final liveEmission = emissions.next;
    await untilLiveSubscriptions(2);
    liveBuckets.add(currentBuckets);

    expect(await liveEmission, currentBuckets);

    await emissions.cancel();
    await service.dispose();
  });

  test('does not reuse buckets cached for other timeline users', () async {
    await seedCache(['user-1'], cachedBuckets);

    final service = createFactory().main(['user-1', 'partner-1']);
    final emissions = StreamQueue(service.watchBuckets());

    final firstEmission = emissions.next;
    await untilLiveSubscriptions(2);
    liveBuckets.add(currentBuckets);

    expect(await firstEmission, currentBuckets);

    await emissions.cancel();
    await service.dispose();
  });

  test('pending main timeline stays empty and does not query the database', () async {
    final service = createFactory().pendingMain();
    final emissions = <List<Bucket>>[];
    final subscription = service.watchBuckets().listen(emissions.add);
    await pumpEventQueue();

    expect(emissions, isEmpty);
    expect(service.totalAssets, 0);
    verifyNever(() => timelineRepository.main(any(), any()));

    await subscription.cancel();
    await service.dispose();
  });
}
