import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection.dart';
import '../../../core/observability/diagnostics_log.dart';
import '../../../core/storage/hive_service.dart';
import 'models/monitoring_draft.dart';

/// Keeps unfinished monitoring forms on disk.
///
/// There is no server side to this: a draft is private to the device until the
/// inspector finishes the form. That is the point — it has to survive with no
/// connection at all.
abstract final class MonitoringDraftStore {
  static const _tag = 'draft';

  /// Photos are copied here instead of being referenced where the camera left
  /// them. `image_picker` returns a file in the temporary directory, which the
  /// system is free to delete whenever it wants space — which is exactly when
  /// a long form is most likely to be interrupted.
  static const _photoDirName = 'monitoring_drafts';

  static Box<dynamic> get _box => getIt<HiveService>().monitoringDraftBox;

  /// Reads synchronously on purpose: the form restores itself in `initState`,
  /// so the fields are filled on the first frame rather than appearing a
  /// moment later under the inspector's thumb.
  static MonitoringDraft? read(String key) {
    final raw = _box.get(key);
    if (raw is! Map) return null;
    try {
      return MonitoringDraft.fromMap(raw);
    } catch (error) {
      // A draft written by an older version of the app is not worth a crash
      // on the way into the form.
      DiagnosticsLog.warn(_tag, 'could not read a draft', error: error);
      return null;
    }
  }

  static Future<void> write(String key, MonitoringDraft draft) async {
    // An untouched form must not leave a draft, or every visit to the page
    // would announce a restore of nothing.
    if (draft.isEmpty) return delete(key);
    try {
      await _box.put(key, draft.toMap());
    } catch (error) {
      DiagnosticsLog.error(_tag, 'could not save a draft', error: error);
    }
  }

  /// Removes the draft and the photos only it was holding.
  static Future<void> delete(String key) async {
    final draft = read(key);
    try {
      await _box.delete(key);
    } catch (error) {
      DiagnosticsLog.error(_tag, 'could not delete a draft', error: error);
    }
    for (final path in draft?.imagePaths ?? const <String>[]) {
      await deletePhoto(path);
    }
  }

  /// Copies a freshly taken photo somewhere it will still be tomorrow and
  /// returns the new path.
  ///
  /// Returns the original path when the copy fails: a photo in the temporary
  /// directory is worth more than no photo, it just may not survive.
  static Future<String> persistPhoto(XFile photo) async {
    try {
      final dir = await _photoDir();
      final name = '${DateTime.now().microsecondsSinceEpoch}_${photo.name}';
      final target = '${dir.path}/$name';
      await File(photo.path).copy(target);
      return target;
    } catch (error) {
      DiagnosticsLog.warn(_tag, 'could not store a photo', error: error);
      return photo.path;
    }
  }

  static Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      // A leftover file costs disk space and nothing else.
      DiagnosticsLog.warn(_tag, 'could not delete a photo', error: error);
    }
  }

  /// Every draft and every photo. Called on logout, where leaving one
  /// inspector's field notes for the next one is the thing to avoid.
  static Future<void> clear() async {
    try {
      await _box.clear();
    } catch (error) {
      DiagnosticsLog.error(_tag, 'could not clear the drafts', error: error);
    }
    try {
      final dir = await _photoDir();
      await dir.delete(recursive: true);
    } catch (error) {
      DiagnosticsLog.warn(
        _tag,
        'could not clear the draft photos',
        error: error,
      );
    }
  }

  static Future<Directory> _photoDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_photoDirName');
    // Created on demand rather than in an init() called from main(): the
    // directory is only needed once a photo is actually taken.
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
