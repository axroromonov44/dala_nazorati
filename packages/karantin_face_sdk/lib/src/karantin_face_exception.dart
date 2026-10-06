/// Error thrown by the Karantin ID face flow.
class KarantinFaceException implements Exception {
  const KarantinFaceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'KarantinFaceException($statusCode): $message';
}
