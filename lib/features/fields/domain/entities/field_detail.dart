import 'package:equatable/equatable.dart';
import 'field_summary.dart';

/// A single photo attached to a field. Only the remote URLs are part of the
/// entity — the actual bytes are fetched/cached on disk by `FieldMediaCache`
/// only once a photo is actually viewed.
class FieldPhoto extends Equatable {
  const FieldPhoto({
    required this.id,
    required this.remoteUrl,
    this.thumbUrl,
  });

  final String id;
  final String remoteUrl;
  final String? thumbUrl;

  @override
  List<Object?> get props => [id, remoteUrl, thumbUrl];
}

/// Full field record — description, crop/plant info, and photo metadata.
/// Fetched and cached only when a field is opened, never as part of the
/// always-on map index sync (that's what keeps steady-state offline storage
/// small regardless of how many fields exist).
class FieldDetail extends Equatable {
  const FieldDetail({
    required this.summary,
    required this.description,
    required this.plantInfo,
    required this.photos,
  });

  final FieldSummary summary;
  final String description;
  final String plantInfo;
  final List<FieldPhoto> photos;

  @override
  List<Object?> get props => [summary, description, plantInfo, photos];
}
