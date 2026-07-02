import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_service.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dioService);

  final DioService _dioService;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _dioService.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'username': username, 'password': password},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> loginGov({required String code}) async {
    final response = await _dioService.post<Map<String, dynamic>>(
      ApiEndpoints.govLogin,
      queryParameters: {'code': code},
    );
    return response.data!;
  }
}
