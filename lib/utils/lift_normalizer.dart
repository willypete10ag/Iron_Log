// lib/utils/lift_normalizer.dart
import '../data/canonical_lifts.dart';

class LiftMatch {
  final String id;
  final String displayName;
  const LiftMatch(this.id, this.displayName);
}

String _normalizeKey(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[\u2190-\u21FF]'), ' ') // arrows etc.
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')      // punctuation → space
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Try to match any user-entered name to the canonical list.
/// Returns a LiftMatch if we find a direct key match on display name or any alias.
LiftMatch? matchLift(String raw) {
  final key = _normalizeKey(raw);
  for (final c in canonicalLifts) {
    final displayKey = _normalizeKey(c.displayName);
    if (displayKey == key) return LiftMatch(c.id, c.displayName);
    for (final a in c.aliases) {
      if (_normalizeKey(a) == key) return LiftMatch(c.id, c.displayName);
    }
  }
  // no direct match
  return null;
}

/// Return the canonical group name for a given canonical lift ID.
String? groupForCanonicalId(String id) => canonicalIdToGroup[id];

/// Return all known group names in display order.
Set<String> allGroups() => Set<String>.from(kCanonicalGroups);

/// Check if a given group name exists in canonical definitions.
bool isCanonicalGroup(String name) =>
    kCanonicalGroups.contains(name.trim());

/// Title-case utility used as fallback (keeps your existing behavior)
String toTitleCase(String text) {
  return text
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
