import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:dala_nazorati/features/reference/data/reference_image_cache.dart';

/// The cache names files after the URL. Those names must survive app restarts
/// and Dart SDK upgrades, and files written by the previous `String.hashCode`
/// scheme must be adopted rather than downloaded again — the catalog is roughly
/// two thousand images.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory imagesDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('reference_image_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await ReferenceImageCache.init();
    imagesDir = Directory('${root.path}/reference_images');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  const url =
      'https://s3.efito.uz/datahub/media/pest_images/image_abc123_XyZ.png';
  final md5Name = '${md5.convert(utf8.encode(url))}.png';
  final legacyName = '${url.hashCode.toUnsigned(32).toRadixString(16)}.png';

  test('init creates the cache directory', () async {
    expect(imagesDir.existsSync(), isTrue);
  });

  test('an uncached url has no file', () {
    expect(ReferenceImageCache.cachedFile(url), isNull);
  });

  test('a file stored under the md5 name is found', () {
    File('${imagesDir.path}/$md5Name').writeAsBytesSync([1, 2, 3]);

    final file = ReferenceImageCache.cachedFile(url);
    expect(file, isNotNull);
    expect(file!.path, endsWith(md5Name));
    expect(file.readAsBytesSync(), [1, 2, 3]);
  });

  test('a legacy hashCode file is adopted and renamed, not re-downloaded', () {
    File('${imagesDir.path}/$legacyName').writeAsBytesSync([9, 9]);
    expect(legacyName, isNot(md5Name));

    final file = ReferenceImageCache.cachedFile(url);

    expect(file, isNotNull, reason: 'the old file should still be usable');
    expect(file!.readAsBytesSync(), [9, 9]);
    expect(file.path, endsWith(md5Name), reason: 'it should be renamed');
    expect(
      File('${imagesDir.path}/$legacyName').existsSync(),
      isFalse,
      reason: 'the legacy copy should be gone, not duplicated',
    );

    // And the second lookup finds it straight away under the new name.
    expect(ReferenceImageCache.cachedFile(url)!.path, endsWith(md5Name));
  });

  test('different urls never share a file name', () {
    const other =
        'https://s3.efito.uz/datahub/media/pest_images/image_def456_AbC.png';
    File('${imagesDir.path}/$md5Name').writeAsBytesSync([1]);

    expect(ReferenceImageCache.cachedFile(url), isNotNull);
    expect(ReferenceImageCache.cachedFile(other), isNull);
  });

  test('the extension is taken from the url, ignoring the query', () {
    const jpg = 'https://example.com/a/b/photo_1.jpg?v=2';
    final name = '${md5.convert(utf8.encode(jpg))}.jpg';
    File('${imagesDir.path}/$name').writeAsBytesSync([1]);

    expect(ReferenceImageCache.cachedFile(jpg)?.path, endsWith('.jpg'));
  });

  test('downloadAll does nothing when everything is already cached', () async {
    File('${imagesDir.path}/$md5Name').writeAsBytesSync([1]);

    // No network is available in tests, so this only passes if the already
    // cached url is skipped outright.
    await ReferenceImageCache.downloadAll([url]);
  });

  test('clear empties the directory but keeps it usable', () async {
    File('${imagesDir.path}/$md5Name').writeAsBytesSync([1]);

    await ReferenceImageCache.clear();

    expect(imagesDir.existsSync(), isTrue);
    expect(imagesDir.listSync(), isEmpty);
    expect(ReferenceImageCache.cachedFile(url), isNull);
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}
