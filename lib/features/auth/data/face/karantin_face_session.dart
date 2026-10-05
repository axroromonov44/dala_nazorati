/// Which OAuth sub-flow the karantin-id backend handed us after `authorize`.
///
/// The `authorize` endpoint 302-redirects the client to one of the SPA routes
/// depending on `auth_type` and account state:
///   * `/sign-in?token=…&name=…`      -> [login]
///   * `/sign-up?code=…&state=…`      -> [register]
///   * `/verify-document?token=…`     -> [verifyDocument]
enum KarantinFaceFlow { login, register, verifyDocument }

/// The session parameters parsed out of the `authorize` redirect. These are the
/// same values the web SPA read from its URL before starting the face scan.
class KarantinFaceSession {
  const KarantinFaceSession({
    required this.flow,
    this.token,
    this.name,
    this.code,
    this.state,
  });

  final KarantinFaceFlow flow;

  /// JWT used by the login / verify-document flows (`token` query param).
  final String? token;

  /// Human-readable target system name, shown in the UI ("Tizim: …").
  final String? name;

  /// One-time code used by the register flow (`code` query param -> one_code).
  final String? code;

  /// Register flow state blob: "clientId,isNotDeepened,token".
  final String? state;

  /// Register state parts, mirroring `parseRegisterState`.
  ({String clientId, bool isNotDeepened, String? token}) get registerState {
    final parts = (state ?? '').split(',');
    return (
      clientId: parts.isNotEmpty ? parts[0] : '',
      isNotDeepened: parts.length > 1 && parts[1] == 'true',
      token: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }
}
