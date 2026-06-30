import '../../../../core/network/dio_service.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dioService);

  final DioService _dioService;

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _dioService.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    return response.data!;
  }
}
