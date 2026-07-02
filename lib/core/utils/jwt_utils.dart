import 'dart:convert';

/// JWT payload qismini (imzosini tekshirmasdan) dekodlaydi.
/// Backend allaqachon ishonchli manba bo'lgani uchun bu yerda faqat
/// tokendagi claim'larni (user_id, username, roles va h.k.) o'qish uchun ishlatiladi.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Yaroqsiz token formati');
  }
  final normalized = base64Url.normalize(parts[1]);
  final payload = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(payload) as Map<String, dynamic>;
}
