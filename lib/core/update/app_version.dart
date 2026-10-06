/// Semantic version comparison.
///
/// Remote Config hands over a string like `"1.4.0"` and `package_info_plus`
/// reports what is installed. Comparing them as text is wrong:
/// `"1.10.0" < "1.9.0"`, because alphabetically `0` follows `1`. So each
/// component is compared as a number.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  /// `"1.4.2"`, `"1.4"` and `"1.4.2+18"` are all accepted. The build number
  /// (`+18`) is ignored: it is for the stores, not for the user.
  ///
  /// Returns `null` for anything unparseable, which means no update is asked
  /// for. Locking every user out because of a typo in Remote Config would be
  /// the worst possible outcome.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim().split('+').first;
    if (cleaned.isEmpty) return null;

    final parts = <int>[];
    for (final piece in cleaned.split('.')) {
      final value = int.tryParse(piece.trim());
      if (value == null || value < 0) return null;
      parts.add(value);
    }
    return parts.isEmpty ? null : AppVersion(parts);
  }

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      // A missing component counts as zero, so "1.4" equals "1.4.0".
      final mine = i < parts.length ? parts[i] : 0;
      final theirs = i < other.parts.length ? other.parts[i] : 0;
      if (mine != theirs) return mine.compareTo(theirs);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => parts.join('.');
}

/// What should happen given the installed version.
enum UpdateRequirement {
  /// Nothing to do.
  none,

  /// A newer version exists, but carrying on is fine.
  optional,

  /// This version is no longer supported — the app cannot be used.
  required,
}

/// Compares the installed [current] version against the Remote Config values.
///
/// Anything below [minimumSupported] must update (for example because the
/// backend dropped the old API). [latest] is the newest released version.
UpdateRequirement resolveUpdateRequirement({
  required String current,
  String? minimumSupported,
  String? latest,
}) {
  final installed = AppVersion.tryParse(current);
  // If the installed version cannot be read, never lock the user out.
  if (installed == null) return UpdateRequirement.none;

  final minimum = AppVersion.tryParse(minimumSupported);
  if (minimum != null && installed < minimum) return UpdateRequirement.required;

  final newest = AppVersion.tryParse(latest);
  if (newest != null && installed < newest) return UpdateRequirement.optional;

  return UpdateRequirement.none;
}
