import 'package:equatable/equatable.dart';
import 'field_summary.dart';

class FieldPhoto extends Equatable {
  const FieldPhoto({required this.id, required this.remoteUrl, this.thumbUrl});

  final String id;
  final String remoteUrl;
  final String? thumbUrl;

  @override
  List<Object?> get props => [id, remoteUrl, thumbUrl];
}

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
