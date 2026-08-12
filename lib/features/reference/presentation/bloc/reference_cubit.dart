import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/plant.dart';
import '../../domain/repositories/reference_repository.dart';

class ReferenceCubit extends Cubit<List<Plant>> {
  ReferenceCubit(this._repository) : super(const []) {
    _load();
  }

  final ReferenceRepository _repository;

  Future<void> _load() async {
    final plants = await _repository.getPlants();
    if (!isClosed) emit(plants);
  }
}
