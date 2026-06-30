import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._connectivity) : super(true) {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    emit(_isOnline(result));
    _sub = _connectivity.onConnectivityChanged.listen(
      (results) => emit(_isOnline(results)),
    );
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
