/// Which inspectorate the signed-in user belongs to.
///
/// The role is never chosen by hand — it is derived from the `roles` claim the
/// backend puts in the access token, so logging in with a password, OneID,
/// Karantin ID or Face ID all land on the same answer.
enum InspectorRole {
  /// Plant quarantine inspector.
  karantin('roleKarantinInspector'),

  /// Veterinary inspector.
  veterinary('roleVetInspector'),

  /// Sanitary-epidemiological service inspector.
  ses('roleSesInspector');

  const InspectorRole(this.labelKey);

  /// easy_localization key for the inspector's title.
  final String labelKey;
}

/// Exact role codes the backend issues, per inspectorate.
///
/// Matching is case-insensitive. Keep this table as the source of truth: when
/// the backend adds or renames a code, add it here rather than relying on
/// [_keywords] below, which is only a safety net for codes we have not seen.
const Map<InspectorRole, Set<String>> kInspectorRoleCodes = {
  InspectorRole.karantin: {
    'karantin_inspector',
    'quarantine_inspector',
    'inspector_karantin',
    'karantin',
  },
  InspectorRole.veterinary: {
    'vet_inspector',
    'veterinary_inspector',
    'inspector_vet',
    'veterinariya',
    'vet',
  },
  InspectorRole.ses: {
    'ses_inspector',
    'sanitary_inspector',
    'inspector_ses',
    'ses',
  },
};

/// Safety net for codes absent from [kInspectorRoleCodes].
///
/// [_Keyword.fragments] are long enough to be unambiguous anywhere in the
/// string. [_Keyword.words] are too short for that — `ses` alone appears
/// inside "processes" — so they only ever match a whole word.
///
/// Order matters: quarantine runs first because "phytosanitary" contains
/// "sanitar", which would otherwise be read as SES.
typedef _Keyword = ({
  InspectorRole role,
  List<String> fragments,
  Set<String> words,
});

const List<_Keyword> _keywords = [
  (
    role: InspectorRole.karantin,
    fragments: ['karantin', 'quarantine', 'fitosanitar', 'phytosanitary'],
    words: <String>{},
  ),
  (role: InspectorRole.veterinary, fragments: ['veterinar'], words: {'vet'}),
  (
    role: InspectorRole.ses,
    fragments: ['sanepid', 'epidemiolog', 'sanitar', 'sanitary'],
    words: {'ses'},
  ),
];

final _wordSplitter = RegExp(r'[^a-z0-9]+');

InspectorRole? _matchKeywords(String text) {
  final words = text.split(_wordSplitter).where((w) => w.isNotEmpty).toSet();
  for (final k in _keywords) {
    if (k.fragments.any(text.contains)) return k.role;
    if (k.words.intersection(words).isNotEmpty) return k.role;
  }
  return null;
}

/// Resolves the inspectorate from the token's `roles` claim.
///
/// [position] is consulted only as a last resort — it is a free-text job title
/// ("Karantin inspektori"), so it is far less reliable than a role code.
/// Returns `null` when nothing matches, which the UI shows as a plain
/// "Inspektor" rather than guessing an inspectorate the user may not belong to.
InspectorRole? resolveInspectorRole(List<String> roles, {String? position}) {
  final normalized = roles
      .map((r) => r.trim().toLowerCase())
      .where((r) => r.isNotEmpty)
      .toList();

  // An exact code anywhere in the claim outranks every keyword guess.
  for (final code in normalized) {
    for (final entry in kInspectorRoleCodes.entries) {
      if (entry.value.contains(code)) return entry.key;
    }
  }

  for (final code in normalized) {
    final match = _matchKeywords(code);
    if (match != null) return match;
  }

  final title = position?.trim().toLowerCase();
  if (title != null && title.isNotEmpty) return _matchKeywords(title);

  return null;
}
