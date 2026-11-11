/// Public labels must never fall back to an account email address.
String publicDisplayName(Iterable<Object?> candidates,
    {String fallback = '익명 사용자'}) {
  for (final candidate in candidates) {
    if (candidate is! String) continue;
    final name = candidate.trim();
    // Conservatively hide email-like values, including display-name wrappers.
    if (name.isNotEmpty && !name.contains('@')) return name;
  }
  return fallback;
}
