import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Holds the `GET /users/me` profile (username/full name/phone) for the
/// whole app — provided once at the app root (see `app.dart`), so any
/// screen can just read [state] instead of firing its own request.
///
/// The network fetch itself only ever runs once per app session (see
/// [refresh]) — the home page triggers it on first load, and every other
/// screen (drawer, settings, etc.) reuses whatever's already in [state].
class ProfileCubit extends Cubit<User?> {
  ProfileCubit(this._authRepository, this._hiveService) : super(null) {
    unawaited(_loadCached());
  }

  final AuthRepository _authRepository;
  final HiveService _hiveService;
  bool _refreshed = false;

  /// Shows whatever was persisted from the last successful [refresh] (see
  /// `AuthRepositoryImpl.fetchProfile`) immediately, before the network
  /// call below has a chance to complete — so a cold, offline app start
  /// still has a name/phone to show right away.
  Future<void> _loadCached() async {
    final raw = _hiveService.userBox.get(StorageKeys.userData) as String?;
    if (raw == null) return;
    final previous = await _authRepository.getCurrentUser();
    if (previous == null || isClosed) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    emit(UserModel.fromMeResponse(json, previous: previous));
  }

  /// Fetches the authoritative profile from the network — a no-op on every
  /// call after the first successful one in this app session, so calling
  /// it again (e.g. revisiting the home page) doesn't re-request. Pass
  /// [force] to bypass that guard (e.g. after the user edits their own
  /// profile elsewhere and the cache needs to be invalidated).
  Future<void> refresh({bool force = false}) async {
    if (_refreshed && !force) return;
    _refreshed = true;
    try {
      final user = await _authRepository.fetchProfile();
      if (!isClosed) emit(user);
    } catch (_) {
      // Oflayn yoki so'rov muvaffaqiyatsiz tugadi — keyingi chaqiruvda
      // (masalan xarita keyingi safar ochilganda) qayta urinib ko'rish
      // uchun himoya bekor qilinadi.
      _refreshed = false;
    }
  }

  /// Chiqish (logout) paytida chaqiriladi — bu bitta nusxa (singleton)
  /// bo'lgani uchun, aks holda keyingi foydalanuvchi login qilganda ham
  /// oldingisining ismi/rasmi bir lahza ko'rinib turardi va [refresh]
  /// himoyasi (`_refreshed`) tufayli qayta so'ralmasdi ham.
  void reset() {
    _refreshed = false;
    emit(null);
  }
}
